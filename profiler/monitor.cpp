#include "monitor.h"

#include <assert.h>
#include <errno.h>
#include <getopt.h>
#include <linux/perf_event.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>

#include <algorithm>
#include <chrono>
#include <iostream>
#include <sstream>
#include <thread>
#include <tuple>

#include <Python.h>
#include <cstdlib>
#include <cstring>
#include <stdexcept>

Monitor monitor = Monitor();
std::vector<int> cores_g;

// Takeaways (for uncore monitoring):
// (1) For perf_event_attr.type, specify the integer value for individual PMU instead of PERF_TYPE_RAW
// (2) Do not enable perf_event_attr.exclude_kernel
// (3) In the hardware I use, I need to set precise_ip = 0 (i.e., PEBS won't work).
//     Newer hardware may support PEBS for uncore monitoring.
// (4) uncore monitoring is per-socket (i.e., no per-core or per-process monitoring)

static int perf_event_open(struct perf_event_attr *hw_event, pid_t pid,
                           int cpu, int group_fd, unsigned long flags) {
    int ret = syscall(__NR_perf_event_open, hw_event, pid, cpu,
                      group_fd, flags);
    return ret;
}

ApplicationInfo::ApplicationInfo(std::string app_name) {
    pid = -1;
    process_exists = false;
    name = app_name;
}

ApplicationInfo::~ApplicationInfo() {
}

LatencyInfoPerCore::LatencyInfoPerCore(int cpu_id) {
    cpu_id = cpu_id;
    fd_l1d_pend_miss = -1;
    fd_retired_l3_miss = -1;
    curr_count_l1d_pend_miss = 0;
    curr_count_retired_l3_miss = 0;
}

LatencyInfoPerCore::~LatencyInfoPerCore() {
}

LatencyInfoPerProcess::LatencyInfoPerProcess() {
    pid = -1;
    fd_retired_l3_miss = -1;
    fd_cycles_l3_miss = -1;
    curr_count_cycles_l3_miss = 0;
    curr_count_retired_l3_miss = 0;
}



LatencyInfoPerProcess::LatencyInfoPerProcess(int pid) {
    pid = pid;
    fd_retired_l3_miss = -1;
    fd_cycles_l3_miss = -1;
    curr_count_cycles_l3_miss = 0;
    curr_count_retired_l3_miss = 0;
}

LatencyInfoPerProcess::~LatencyInfoPerProcess() {
}

BWInfoPerCore::BWInfoPerCore(int cpu_id) {
    cpu_id = cpu_id;
    fd_offcore_all_reqs = -1;
    curr_count_offcore_all_reqs = 0;
    curr_bw = 0;
}

BWInfoPerCore::~BWInfoPerCore() {
}

PageTempInfoPerCore::PageTempInfoPerCore(int cpu_id, int num_events) {
    cpu_id = cpu_id;
    fds.resize(num_events, -1);
    perf_m_pages.resize(num_events, NULL);
}

// TODO: consider calling munmap for perf pages
PageTempInfoPerCore::~PageTempInfoPerCore() {
}

template<typename A, typename B>
std::pair<B,A> flip_pair(const std::pair<A,B> &p)
{
    return std::pair<B,A>(p.second, p.first);
}

template<typename A, typename B>
std::multimap<B,A> flip_map(const std::map<A,B> &src)
{
    std::multimap<B,A> dst;
    std::transform(src.begin(), src.end(), std::inserter(dst, dst.begin()),
                   flip_pair<A,B>);
    return dst;
}

Monitor::Monitor() {
    is_monitoring_bw_.store(false);
    num_sockets_ = NUM_SOCKETS;
    sampling_period_ms_ = SAMPLING_PERIOD_MS;
    sampling_period_event_ = SAMPLING_PERIOD_EVENT;
    ewma_alpha_ = EWMA_ALPHA;
    num_cpu_throttle_ = 0;
    num_cpu_unthrottle_ = 0;
    num_local_access_ = 0;
    num_remote_access_ = 0;
    for (const auto &x : PMU_CHA_TYPE) {
        pmu_cha_type_.push_back(x);
    }
    for (const auto &x : PMU_IMC_TYPE) {
        pmu_imc_type_.push_back(x);
    }
    fd_rxc_occ_.resize(NUM_SOCKETS);
    fd_rxc_ins_.resize(NUM_SOCKETS);
    fd_cas_rd_.resize(NUM_SOCKETS);
    fd_cas_wr_.resize(NUM_SOCKETS);
    fd_cas_all_.resize(NUM_SOCKETS);
    curr_count_occ_ = std::vector<std::vector<uint64_t>>(num_sockets_,
            std::vector<uint64_t>(pmu_cha_type_.size(), 0));
    curr_count_ins_ = std::vector<std::vector<uint64_t>>(num_sockets_,
            std::vector<uint64_t>(pmu_cha_type_.size(), 0));
    curr_count_rd_ = std::vector<std::vector<uint64_t>>(num_sockets_,
            std::vector<uint64_t>(pmu_imc_type_.size(), 0));
    curr_count_wr_ = std::vector<std::vector<uint64_t>>(num_sockets_,
            std::vector<uint64_t>(pmu_imc_type_.size(), 0));
    bw_read_ = std::vector<std::vector<double>>(num_sockets_,
            std::vector<double>(pmu_imc_type_.size(), 0));
    bw_write_ = std::vector<std::vector<double>>(num_sockets_,
            std::vector<double>(pmu_imc_type_.size(), 0));

    for (int i = 0; i < NUM_CORES; i++) {
        lat_info_cpu_.emplace_back(LatencyInfoPerCore(i));
    }

    for (int i = 0; i < NUM_CORES; i++) {
        bw_info_cpu_.emplace_back(BWInfoPerCore(i));
    }

    page_temp_events_ = {EVENT_MEM_LOAD_L3_MISS_RETIRED_LOCAL_DRAM, EVENT_MEM_LOAD_L3_MISS_RETIRED_REMOTE_DRAM};
    for (int i = 0; i < NUM_CORES; i++) {
        page_temp_info_.emplace_back(PageTempInfoPerCore(i, page_temp_events_.size()));
    }

}

// Move constructor
Monitor::Monitor(Monitor&& other) noexcept
    : is_monitoring_bw_(other.is_monitoring_bw_.load()),
    num_sockets_(other.num_sockets_),
    sampling_period_ms_(other.sampling_period_ms_),
    sampling_period_event_(other.sampling_period_event_),
    ewma_alpha_(other.ewma_alpha_),
    num_cpu_throttle_(other.num_cpu_throttle_),
    num_cpu_unthrottle_(other.num_cpu_unthrottle_),
    num_local_access_(other.num_local_access_),
    num_remote_access_(other.num_remote_access_),
    pmu_cha_type_(std::move(other.pmu_cha_type_)),
    pmu_imc_type_(std::move(other.pmu_imc_type_)),
    fd_rxc_occ_(std::move(other.fd_rxc_occ_)),
    fd_rxc_ins_(std::move(other.fd_rxc_ins_)),
    fd_cas_rd_(std::move(other.fd_cas_rd_)),
    fd_cas_wr_(std::move(other.fd_cas_wr_)),
    fd_cas_all_(std::move(other.fd_cas_all_)),
    curr_count_occ_(std::move(other.curr_count_occ_)),
    curr_count_ins_(std::move(other.curr_count_ins_)),
    curr_count_rd_(std::move(other.curr_count_rd_)),
    curr_count_wr_(std::move(other.curr_count_wr_)),
    bw_read_(std::move(other.bw_read_)),
    bw_write_(std::move(other.bw_write_)),
    lat_info_cpu_(std::move(other.lat_info_cpu_)),
    bw_info_cpu_(std::move(other.bw_info_cpu_)),
    page_temp_events_(std::move(other.page_temp_events_)),
    page_temp_info_(std::move(other.page_temp_info_)),
    application_info_(std::move(other.application_info_)),
    bw_core_list_(std::move(other.bw_core_list_)) {
    other.is_monitoring_bw_.store(false);
}

// Move assignment operator
Monitor& Monitor::operator=(Monitor&& other) noexcept {
    if (this != &other) {
        is_monitoring_bw_.store(other.is_monitoring_bw_.load());
        num_sockets_ = other.num_sockets_;
        sampling_period_ms_ = other.sampling_period_ms_;
        sampling_period_event_ = other.sampling_period_event_;
        ewma_alpha_ = other.ewma_alpha_;
        num_cpu_throttle_ = other.num_cpu_throttle_;
        num_cpu_unthrottle_ = other.num_cpu_unthrottle_;
        num_local_access_ = other.num_local_access_;
        num_remote_access_ = other.num_remote_access_;
        pmu_cha_type_ = std::move(other.pmu_cha_type_);
        pmu_imc_type_ = std::move(other.pmu_imc_type_);
        fd_rxc_occ_ = std::move(other.fd_rxc_occ_);
        fd_rxc_ins_ = std::move(other.fd_rxc_ins_);
        fd_cas_rd_ = std::move(other.fd_cas_rd_);
        fd_cas_wr_ = std::move(other.fd_cas_wr_);
        fd_cas_all_ = std::move(other.fd_cas_all_);
        curr_count_occ_ = std::move(other.curr_count_occ_);
        curr_count_ins_ = std::move(other.curr_count_ins_);
        curr_count_rd_ = std::move(other.curr_count_rd_);
        curr_count_wr_ = std::move(other.curr_count_wr_);
        bw_read_ = std::move(other.bw_read_);
        bw_write_ = std::move(other.bw_write_);
        lat_info_cpu_ = std::move(other.lat_info_cpu_);
        bw_info_cpu_ = std::move(other.bw_info_cpu_);
        page_temp_events_ = std::move(other.page_temp_events_);
        page_temp_info_ = std::move(other.page_temp_info_);
        application_info_ = std::move(other.application_info_);
        bw_core_list_ = std::move(other.bw_core_list_);
        other.is_monitoring_bw_.store(false);
    }
    return *this;
}

Monitor::~Monitor() {
    // TODO: delete ApplicationInfo *
}

void Monitor::add_pid(pid_t pid,int cg_index, std::string process_name){
    PidMeasuredInfo the_pmi;
    the_pmi.pid = pid;
    the_pmi.cg_index = cg_index;
    the_pmi.process_name = process_name;
    the_pmi.latency_measured = 0;
    the_pmi.bw_local_measured = 0;
    the_pmi.bw_remote_measured = 0;
    pid_measured_info_map_[pid] = the_pmi;
}

void Monitor::add_application(ApplicationInfo *app_info) {
    // find pid by app name
    int pid = -1;
    bool found_pid = false;
    while (!found_pid) {
        pid = get_pid_from_proc_name(app_info->name);
        if (pid != -1) {
            found_pid = true;
        }
    }
    app_info->pid = pid;
    app_info->process_exists = true;

    application_info_[app_info->pid] = app_info;

    // update the core list to src b/w
    for (const auto &c : app_info->bw_cores) {
        if (bw_core_list_.count(c)) {
            std::cout << "[Error] add_application: bw core (" << c
                      << ") already exists in src's bw core list" << std::endl;
        }
        bw_core_list_.insert(c);
    }
}

void Monitor::perf_event_reset(int fd) {
    int ret = ioctl(fd, PERF_EVENT_IOC_RESET, 0);
    if (ret < 0) {
        std::cout << "[Error] perf_event_reset: " << strerror(errno) << std::endl;
    }
}

void Monitor::perf_event_enable(int fd) {
    int ret = ioctl(fd, PERF_EVENT_IOC_ENABLE, 0);
    if (ret < 0) {
        std::cout << "[Error] perf_event_enable: " << strerror(errno) << std::endl;
    }
}

void Monitor::perf_event_disable(int fd) {
    int ret = ioctl(fd, PERF_EVENT_IOC_DISABLE, 0);
    if (ret < 0) {
        std::cout << "[Error] perf_event_disable: " << strerror(errno) << std::endl;
    }
}

// precise_ip (since Linux 2.6.35)
//              This controls the amount of skid.  Skid is how many instructions execute between an
//              event of interest happening and the kernel being able to stop and record the event.
//              Smaller  skid  is  better  and  allows  more  accurate  reporting  of  which events
//              correspond to which instructions, but hardware is often limited with how small this
//              can be.
//
//              The possible values of this field are the following:
//
//              0  SAMPLE_IP can have arbitrary skid.
//int Monitor::perf_event_setup(int pid, int cpu, int group_fd, uint32_t type, uint64_t event_id, uint64_t extension_event_id) {
//    struct perf_event_attr event_attr;
//    memset(&event_attr, 0, sizeof(event_attr));
//    event_attr.type = type;
//    event_attr.size = sizeof(event_attr);
//    event_attr.config = event_id;
//    event_attr.config1 = extension_event_id;
//    event_attr.disabled = 1;
//    event_attr.inherit = 1;     // includes child process
//    event_attr.precise_ip = 0;
//
//    int ret = perf_event_open(&event_attr, pid, cpu, group_fd, 0);
//    if (ret < 0) {
//        std::cout << "[Error] perf_event_open: " << strerror(errno) << std::endl;
//    }
//    return ret;
//}

int Monitor::perf_event_setup(int pid, int cpu, int group_fd, uint32_t type, uint64_t event_id) {
    struct perf_event_attr event_attr;
    memset(&event_attr, 0, sizeof(event_attr));
    event_attr.type = type;
    event_attr.size = sizeof(event_attr);
    event_attr.config = event_id;
    event_attr.disabled = 1;
    event_attr.inherit = 1;     // includes child process
    event_attr.precise_ip = 0;

    int ret = perf_event_open(&event_attr, pid, cpu, group_fd, 0);
    if (ret < 0) {
        std::cout << "[Error] perf_event_open: " << strerror(errno) << std::endl;
    }
    return ret;
}



double Monitor::sleep_ms(int time) {
    auto start = std::chrono::high_resolution_clock::now();
    std::this_thread::sleep_for(std::chrono::milliseconds(sampling_period_ms_));
    std::chrono::duration<double, std::milli> elapsed = std::chrono::high_resolution_clock::now() - start;
    return elapsed.count();
}

int Monitor::get_pid_from_proc_name(std::string proc_name) {
    std::string cmd = "pidof " + proc_name;
    char pidline[1024] = "";
    FILE *fp = popen(cmd.c_str(), "r");
    fgets(pidline, 1024, fp);

    if (pidline && !pidline[0]) {   // check empty c string
        pclose(fp);
        return -1;
    }

    int pid = strtoul(pidline, NULL, 10);
    pclose(fp);

    return pid;
}



void Monitor::perf_event_setup_process_latency(int pid) {
    auto latinfo = LatencyInfoPerProcess(pid);
    lat_info_process_[pid] = latinfo;

    //  pid > 0 and cpu == -1   This measures the specified process/thread on any CPU.
    //The group_fd argument allows event groups to be created.  An event group has one event which is the group leader.  The leader is created first, with group_fd = -1.

    // config: This  specifies  which  event  you  want,  in conjunction with the type field.
    // If type is PERF_TYPE_RAW, then a custom "raw" config value is  needed.
    // Most  CPUs support  events  that  are  not  covered  by  the  "generalized" events.  These are implementation defined; see your CPU  manual
//    int fd = perf_event_setup(pid, -1, -1, PERF_TYPE_RAW, EVENT_TOR_OCCUPANCY_IA_MISS_DRD, EVENT_TOR_OCCUPANCY_IA_MISS_DRD_Cn_MSR_PMON_BOX_FILTER1);
//    lat_info_process_[pid].fd_occupancy_ia_miss = fd;
//    perf_event_reset(fd);
//
//    fd = perf_event_setup(pid, -1, -1, PERF_TYPE_RAW, EVENT_TOR_INSERTS_IA_MISS_DRD, EVENT_TOR_INSERTS_IA_MISS_DRD_Cn_MSR_PMON_BOX_FILTER1);
//    lat_info_process_[pid].fd_inserts_ia_miss = fd;
//    perf_event_reset(fd);

    int fd = perf_event_setup(pid, -1, -1, PERF_TYPE_RAW, CYCLE_ACTIVITY_CYCLES_L3_MISS);
    lat_info_process_[pid].fd_cycles_l3_miss = fd;
    perf_event_reset(fd);

    fd = perf_event_setup(pid, -1, -1, PERF_TYPE_RAW, EVENT_MEM_LOAD_RETIRED_L3_MISS);
    lat_info_process_[pid].fd_retired_l3_miss = fd;
    perf_event_reset(fd);


}

void Monitor::perf_event_enable_process_latency(int pid) {
    perf_event_enable(lat_info_process_[pid].fd_cycles_l3_miss);
    perf_event_enable(lat_info_process_[pid].fd_retired_l3_miss);
}

void Monitor::perf_event_disable_process_latency(int pid) {
    perf_event_disable(lat_info_process_[pid].fd_cycles_l3_miss);
    perf_event_disable(lat_info_process_[pid].fd_retired_l3_miss);
}

void Monitor::perf_event_read_process_latency(int pid, bool log_latency, ApplicationInfo *app_info) {
    uint64_t count_cycles_l3_miss=0, count_retired_l3_miss=0;
    read(lat_info_process_[pid].fd_cycles_l3_miss, &count_cycles_l3_miss, sizeof(count_cycles_l3_miss));
    read(lat_info_process_[pid].fd_retired_l3_miss, &count_retired_l3_miss, sizeof(count_retired_l3_miss));
    //double latency_cycles = (double) (count_l1d_pend_miss - lat_info_process_[pid].curr_count_l1d_pend_miss)
    //                       / (count_retired_l3_miss - lat_info_process_[pid].curr_count_retired_l3_miss);
    //lat_info_process_[pid].curr_count_occupancy_ia_miss = count_l1d_pend_miss;
    //lat_info_process_[pid].curr_count_inserts_ia_miss = count_retired_l3_miss;
    // double latency_ns = latency_cycles / GHZ;
    /*std::cout<<"fd_occupancy_ia_miss: " << count_occupancy_ia_miss<<std::endl;
    std::cout<<"fd_inserts_ia_miss: "<<count_inserts_ia_miss<<std::endl;
    if (count_inserts_ia_miss == 0) {
        std::cerr << "Error: Division by zero in calculating latency_ns." << std::endl;
        return;
    }*/

    double latency_cycles = (double) (count_cycles_l3_miss - lat_info_process_[pid].curr_count_cycles_l3_miss) / (count_retired_l3_miss - lat_info_process_[pid].curr_count_retired_l3_miss);

    double this_round_cycles_l3_miss = (double) (count_cycles_l3_miss - lat_info_process_[pid].curr_count_cycles_l3_miss);
    double this_round_retired_l3_miss = (double) (count_retired_l3_miss - lat_info_process_[pid].curr_count_retired_l3_miss);

    lat_info_process_[pid].curr_count_cycles_l3_miss = count_cycles_l3_miss;
    lat_info_process_[pid].curr_count_retired_l3_miss = count_retired_l3_miss;
    double latency_ns = latency_cycles / PROCESSOR_GHZ;
    if (log_latency) {
        sampled_process_lat_.push_back(latency_ns);
    }
    if (app_info) {
        std::cout << "App (\"" << app_info->name <<  "\"): latency = " << latency_ns << " ns" << std::endl;
    } else {
        std::cout << "process [" << pid << "]: latency = " << latency_ns << " ns" << std::endl;
    }
    std::cout << "this_round_cycles_l3_miss:" << this_round_cycles_l3_miss << std::endl;
    std::cout << "this_round_retired_l3_miss:" << this_round_retired_l3_miss << std::endl;

    std::cout << "count_cycles_l3_miss: "<<count_cycles_l3_miss<<std::endl;
    std::cout << "count_retired_l3_miss: "<<count_retired_l3_miss<<std::endl;

    std::cout<<std::endl;
}
void Monitor::perf_event_read_and_write_process_latency(pid_t pid, bool log_latency, ApplicationInfo *app_info) {
    uint64_t count_cycles_l3_miss=0, count_retired_l3_miss=0;
    read(lat_info_process_[pid].fd_cycles_l3_miss, &count_cycles_l3_miss, sizeof(count_cycles_l3_miss));
    read(lat_info_process_[pid].fd_retired_l3_miss, &count_retired_l3_miss, sizeof(count_retired_l3_miss));

    double latency_cycles = (double) (count_cycles_l3_miss - lat_info_process_[pid].curr_count_cycles_l3_miss) / (count_retired_l3_miss - lat_info_process_[pid].curr_count_retired_l3_miss);

    double this_round_cycles_l3_miss = (double) (count_cycles_l3_miss - lat_info_process_[pid].curr_count_cycles_l3_miss);
    double this_round_retired_l3_miss = (double) (count_retired_l3_miss - lat_info_process_[pid].curr_count_retired_l3_miss);

    lat_info_process_[pid].curr_count_cycles_l3_miss = count_cycles_l3_miss;
    lat_info_process_[pid].curr_count_retired_l3_miss = count_retired_l3_miss;
    double latency_ns = latency_cycles / PROCESSOR_GHZ;
    // Open file for appending latency measurements
    // std::ofstream latency_file("latency_log.txt", std::ios_base::app);
    // if (!latency_file) {
    //     std::cerr << "Failed to open latency_log.txt" << std::endl;
    //     return;
    // }

    if (log_latency) {
        // Open or create the CSV file in append mode
        std::ofstream latency_file("latency_log.csv", std::ios_base::app);

        if (latency_file.is_open()) {
            // Check if the file is empty; if so, write the header row
            latency_file.seekp(0, std::ios::end);
            if (latency_file.tellp() == 0) {
                latency_file << "Timestamp,PID,Latency (ns)\n";
            }

            // Get the current time
            auto now = std::chrono::system_clock::now();
            std::time_t now_time = std::chrono::system_clock::to_time_t(now);

            // Format and write the timestamp, PID, and latency information to the CSV file
            latency_file << std::put_time(std::localtime(&now_time), "%Y-%m-%d %H:%M:%S") << ","
                         << pid << ","
                         << latency_ns << "\n";

            latency_file.close();
        } else {
            std::cerr << "Failed to open latency_log.csv for writing." << std::endl;
        }
        sampled_process_lat_.push_back(latency_ns);

    }

    if (app_info) {
//        std::cout << "App (\"" << app_info->name <<  "\"): latency = " << latency_ns << " ns" << std::endl;
    } else {
//        std::cout << "process [" << pid << "]: latency = " << latency_ns << " ns" << std::endl;
//        pid_measured_infos_[app_index].latency_measured = latency_ns;
        // Read info from the map based on pid
        auto it = pid_measured_info_map_.find(pid);
        if (it != pid_measured_info_map_.end()) {
            it->second.latency_measured = latency_ns;
        } else {
            std::cout << "Pid " << pid << " not found in the map." << std::endl;
        }

    }
//    std::cout << "this_round_cycles_l3_miss:" << this_round_cycles_l3_miss << std::endl;
//    std::cout << "this_round_retired_l3_miss:" << this_round_retired_l3_miss << std::endl;
//
//    std::cout << "count_cycles_l3_miss: "<<count_cycles_l3_miss<<std::endl;
//    std::cout << "count_retired_l3_miss: "<<count_retired_l3_miss<<std::endl;

    //std::cout<<std::endl;
}

void Monitor::perf_event_read_and_write_process_latency_to_file(pid_t pid, bool log_latency, std::string app_name) {
    uint64_t count_cycles_l3_miss=0, count_retired_l3_miss=0;
    read(lat_info_process_[pid].fd_cycles_l3_miss, &count_cycles_l3_miss, sizeof(count_cycles_l3_miss));
    read(lat_info_process_[pid].fd_retired_l3_miss, &count_retired_l3_miss, sizeof(count_retired_l3_miss));

    double latency_cycles = (double) (count_cycles_l3_miss - lat_info_process_[pid].curr_count_cycles_l3_miss) / (count_retired_l3_miss - lat_info_process_[pid].curr_count_retired_l3_miss);

    double this_round_cycles_l3_miss = (double) (count_cycles_l3_miss - lat_info_process_[pid].curr_count_cycles_l3_miss);
    double this_round_retired_l3_miss = (double) (count_retired_l3_miss - lat_info_process_[pid].curr_count_retired_l3_miss);

    lat_info_process_[pid].curr_count_cycles_l3_miss = count_cycles_l3_miss;
    lat_info_process_[pid].curr_count_retired_l3_miss = count_retired_l3_miss;
    double latency_ns = latency_cycles / PROCESSOR_GHZ;
    // Open file for appending latency measurements
    std::string output_latency_file_name = "latency_log_" + app_name + ".csv";
    if (log_latency) {
        // Open or create the CSV file in append mode
        std::ofstream latency_file(output_latency_file_name, std::ios_base::app);

        if (latency_file.is_open()) {
            // Check if the file is empty; if so, write the header row
            latency_file.seekp(0, std::ios::end);
            if (latency_file.tellp() == 0) {
                latency_file << "Timestamp,PID,Latency (ns)\n";
            }

            // Get the current time
            auto now = std::chrono::system_clock::now();
            std::time_t now_time = std::chrono::system_clock::to_time_t(now);

            // Format and write the timestamp, PID, and latency information to the CSV file
            latency_file << std::put_time(std::localtime(&now_time), "%Y-%m-%d %H:%M:%S") << ","
                         << pid << ","
                         << latency_ns << "\n";

            latency_file.close();
        } else {
            std::cerr << "Failed to open latency_log.csv for writing." << std::endl;
        }
        sampled_process_lat_.push_back(latency_ns);

    }


    auto it = pid_measured_info_map_.find(pid);
    if (it != pid_measured_info_map_.end()) {
        it->second.latency_measured = latency_ns;
    } else {
        std::cout << "Pid " << pid << " not found in the map." << std::endl;
    }


//    std::cout << "this_round_cycles_l3_miss:" << this_round_cycles_l3_miss << std::endl;
//    std::cout << "this_round_retired_l3_miss:" << this_round_retired_l3_miss << std::endl;
//
//    std::cout << "count_cycles_l3_miss: "<<count_cycles_l3_miss<<std::endl;
//    std::cout << "count_retired_l3_miss: "<<count_retired_l3_miss<<std::endl;

    //std::cout<<std::endl;
}

void Monitor::measure_and_write_process_bw_to_file(const std::vector<int>& processIds) {
    // Initialize the Python interpreter
    for (int pid : processIds) {
        std::cout << "monitor: pid in the processIds: " << pid << std::endl;
    }

    Py_Initialize();
    // Ensure the interpreter started successfully
    if (!Py_IsInitialized()) {
        std::cerr << "Error: Failed to initialize Python interpreter." << std::endl;
        return;
    }

    // Add the directory containing your module to the Python path
    PyObject* sysPath = PySys_GetObject("path");
    if (!sysPath) {
        std::cerr << "Error: Failed to get Python path." << std::endl;
        Py_Finalize();
        return;
    }


    PyList_Append(sysPath, PyUnicode_FromString("../")); // because the executable file is in the build dir


    // Import the Python module
    PyObject* pName = PyUnicode_FromString("monitoring");
    PyObject* pModule = PyImport_Import(pName);
    Py_DECREF(pName);

    if (pModule != nullptr) {
        // Get the reference to the function
        PyObject* pFunc = PyObject_GetAttrString(pModule, "run_monitor");

        if (pFunc && PyCallable_Check(pFunc)) {
            // Create a Python list for process IDs
            PyObject* pListProcessIds = PyList_New(processIds.size());
            for (size_t i = 0; i < processIds.size(); ++i) {
                PyList_SetItem(pListProcessIds, i, PyLong_FromLong(processIds[i]));
            }

            // Prepare arguments for the Python function call
            PyObject* pArgs = PyTuple_New(1);
            PyTuple_SetItem(pArgs, 0, pListProcessIds); // Tuple takes ownership

            PyObject* pGenerator = PyObject_CallObject(pFunc, pArgs); // This is now expected to be a generator

            if (pGenerator) {
                PyObject* pItem;
                while ((pItem = PyIter_Next(pGenerator)) != nullptr) {
                    if (PyDict_Check(pItem)) {
                        PyObject *key, *value;
                        Py_ssize_t pos = 0;


                        while (PyDict_Next(pItem, &pos, &key, &value)) {
                            if (PyLong_Check(key)) {
                                long pid = PyLong_AsLong(key);

                                // Assume `value` is a dictionary with 'llc', 'mbl', 'mbr'
                                PyObject* pLLC = PyDict_GetItemString(value, "llc");
                                PyObject* pMBL = PyDict_GetItemString(value, "mbl");
                                PyObject* pMBR = PyDict_GetItemString(value, "mbr");

                                if (pLLC && pMBL && pMBR) {
                                    double llc = PyFloat_AsDouble(pLLC);
                                    double mbl = PyFloat_AsDouble(pMBL);
                                    double mbr = PyFloat_AsDouble(pMBR);

//                                    std::cout << "PID: " << pid << "  llc: " << llc
//                                              << ", mbl: " << mbl << ", mbr: " << mbr << std::endl;
                                    std::time_t now = std::time(nullptr);
                                    char time_str[100];
                                    std::strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", std::localtime(&now));

                                    // Save the bandwidth information to a CSV file
                                    std::ofstream outfile;
                                    std::string filename;
                                    auto it = pid_measured_info_map_.find(pid); // the actual value is changed when using it->second
                                    if (it != pid_measured_info_map_.end()) {
                                        it->second.bw_local_measured = mbl;
                                        it->second.bw_remote_measured = mbr;
                                        filename = "bandwidth_log_" + it->second.process_name + ".csv"; // Use .csv extension
                                    } else {
                                        std::cout << "Pid " << pid << " not found in the map." << std::endl;
                                    }

                                    // Open the file in append mode
                                    outfile.open(filename, std::ios_base::app);
                                    if (outfile.is_open()) {
                                        // Write a header if the file is empty
                                        if (outfile.tellp() == 0) { // Check if the file is empty
                                            outfile << "Timestamp,LLC,MBL,MBR" << std::endl; // CSV header
                                        }
                                        // Append the data in CSV format
                                        outfile << time_str << "," << llc << "," << mbl << "," << mbr << std::endl;
                                        outfile.close();
                                    } else {
                                        std::cerr << "Error: Could not open file " << filename << " for writing." << std::endl;
                                    }


                                }
                            }
                        }
                    }
                    Py_DECREF(pItem);
                }

                if (PyErr_Occurred()) PyErr_Print();
                Py_DECREF(pGenerator);
            } else {
                PyErr_Print();
                std::cerr << "Call to \"run_monitor\" did not return a generator." << std::endl;
            }

            Py_DECREF(pArgs);
        } else {
            PyErr_Print();
        }

        Py_DECREF(pModule);
    } else {
        PyErr_Print();
    }

    // Clean up and shut down the Python interpreter
    Py_Finalize();
}


void Monitor::measure_process_latency(int pid) {
    perf_event_setup_process_latency(pid);

    for (;;) {
        perf_event_enable_process_latency(pid);

        sleep_ms(sampling_period_ms_);

        perf_event_disable_process_latency(pid);
        perf_event_read_process_latency(pid);
    }
}
double Monitor::read_process_latency(pid_t pid){
    double latency_ns;
    auto it = pid_measured_info_map_.find(pid);
    if (it != pid_measured_info_map_.end()) {
        latency_ns = it->second.latency_measured;
    } else {
        std::cout << "Pid " << pid << " not found in the map." << std::endl;
    }
    return latency_ns;
}

double Monitor::read_process_total_bw(pid_t pid){
    auto it = pid_measured_info_map_.find(pid);
    if (it != pid_measured_info_map_.end()) {
        return it->second.bw_local_measured + it->second.bw_remote_measured;
    } else {
        std::cout<<"can not find this pid: "<< pid << std::endl;
        return 0;
    }

}

double Monitor::read_process_top_tier_bw(pid_t pid){
    auto it = pid_measured_info_map_.find(pid);
    if (it != pid_measured_info_map_.end()) {
        return it->second.bw_local_measured;
    } else {
        std::cout<<"can not find this pid: "<< pid << std::endl;
        return 0;
    }
}

void Monitor::measure_and_write_process_latency(pid_t pid) {
    perf_event_setup_process_latency(pid);

    for (;;) {
        perf_event_enable_process_latency(pid);

        sleep_ms(sampling_period_ms_);

        perf_event_disable_process_latency(pid);
        perf_event_read_and_write_process_latency(pid, true);
//        perf_event_read_process_latency(pid);

    }
}
void Monitor::measure_and_write_process_latency_to_file(pid_t pid, std::string app_name) {
    perf_event_setup_process_latency(pid);

    for (;;) {
        perf_event_enable_process_latency(pid);

        sleep_ms(sampling_period_ms_);

        perf_event_disable_process_latency(pid);
        perf_event_read_and_write_process_latency_to_file(pid, true,app_name);
//        perf_event_read_process_latency(pid);

    }
}


void Monitor::measure_process_latency(std::string proc_name) {
    // get pid first via process name
    int pid = -1;
    bool found_pid = false;
    while (!found_pid) {
        pid = get_pid_from_proc_name(proc_name);
        if (pid != -1) {
            std::cout << "Start measuring latency for " << proc_name << "(" << pid << ") ..." << std::endl;
            found_pid = true;
        }
    }

    // measure latency given the pid; always check if the process still exists
    bool process_exists = true;

    perf_event_setup_process_latency(pid);

    while (process_exists) {
        perf_event_enable_process_latency(pid);

        sleep_ms(sampling_period_ms_);

        perf_event_disable_process_latency(pid);
        perf_event_read_process_latency(pid);

        if (get_pid_from_proc_name(proc_name) == -1) {
            process_exists = false;
        }
    }

    if (!sampled_process_lat_.empty()) {
        double sum_lat = 0;
        std::cout << "sampled latency = [";
        int i = 0;
        for (; i < sampled_process_lat_.size() - 1; i++) {
            std::cout << int(sampled_process_lat_[i]) << ",";
            sum_lat += sampled_process_lat_[i];
        }
        std::cout << int(sampled_process_lat_[i]) << "]" << std::endl;
        sum_lat += sampled_process_lat_[i];
        std::sort(sampled_process_lat_.begin() + sampled_process_lat_.size() * 0.1, sampled_process_lat_.begin() + sampled_process_lat_.size() * 0.9);
        double avg_lat = sum_lat / sampled_process_lat_.size();
        int medium = sampled_process_lat_[sampled_process_lat_.size() * 0.5];
        std::cout << "avg sampled latency = " << avg_lat << std::endl;
        std::cout << "Medium Sampled Latency = " << medium << std::endl;
    }

    std::cout << proc_name << " no longer exists. Stop measuring." << std::endl;
}

void Monitor::measure_application_latency() {
    for (const auto &[pid, app] : application_info_) {
        perf_event_setup_process_latency(pid);
    }

    for (;;) {
        for (const auto &[pid, app] : application_info_) {
            if (app->process_exists) {
                perf_event_enable_process_latency(pid);
            }
        }

        sleep_ms(sampling_period_ms_);

        for (const auto &[pid, app] : application_info_) {
            if (app->process_exists) {
                perf_event_disable_process_latency(pid);
                perf_event_read_process_latency(pid, false, app);
            }
        }

        for (const auto &[pid, app] : application_info_) {
            if (get_pid_from_proc_name(app->name) == -1) {
                app->process_exists = false;
            }
            //} else {
            //    app->process_exists = true;     // shall we do this?
            //}
        }
    }
}


// Define the struct as shown above
struct BandwidthData {
    double llc;
    double mbl;
    double mbr;
};


// Function to call the Python function and process its return values
void print_process_bw(int processId) {
    // Initialize the Python interpreter
    Py_Initialize();

    // Ensure the interpreter started successfully
    if (!Py_IsInitialized()) {
        std::cerr << "Error: Failed to initialize Python interpreter." << std::endl;
        return;
    }

    // Add the directory containing your module to the Python path
    PyObject* sysPath = PySys_GetObject("path");
    if (!sysPath) {
        std::cerr << "Error: Failed to get Python path." << std::endl;
        Py_Finalize();
        return;
    }

    PyList_Append(sysPath, PyUnicode_FromString("../")); // Adjust as necessary

    // Import the Python module
    PyObject* pName = PyUnicode_FromString("monitoring");
    PyObject* pModule = PyImport_Import(pName);
    Py_DECREF(pName);

    if (pModule != nullptr) {
        // Get the reference to the function
        PyObject* pFunc = PyObject_GetAttrString(pModule, "run_monitor");

        if (pFunc && PyCallable_Check(pFunc)) {
            PyObject* pArgs = PyTuple_New(1);
            PyObject* pValueProcessId = PyLong_FromLong(processId);
            PyTuple_SetItem(pArgs, 0, pValueProcessId);

            PyObject* pGenerator = PyObject_CallObject(pFunc, pArgs); // This is now expected to be a generator

            if (pGenerator) {
                PyObject* pItem;
                while ((pItem = PyIter_Next(pGenerator)) != nullptr) {
                    if (PyDict_Check(pItem)) {
                        PyObject* pLLC = PyDict_GetItemString(pItem, "llc");
                        PyObject* pMBL = PyDict_GetItemString(pItem, "mbl");
                        PyObject* pMBR = PyDict_GetItemString(pItem, "mbr");

                        if (pLLC && pMBL && pMBR) {
                            double llc = PyFloat_AsDouble(pLLC);
                            double mbl = PyFloat_AsDouble(pMBL);
                            double mbr = PyFloat_AsDouble(pMBR);

                            // Use the data as needed
                            std::cout << "llc: " << llc << " mbl: " << mbl << " mbr: " << mbr << std::endl;
                        }
                        Py_DECREF(pItem); // Avoid memory leak
                    }
                }

                if (PyErr_Occurred()) {
                    PyErr_Print(); // Handle any errors that occurred in the iterator
                }

                Py_DECREF(pGenerator);
            } else {
                PyErr_Print();
                std::cerr << "Call to \"run_monitor\" did not return a generator." << std::endl;
            }

            Py_DECREF(pArgs);
        } else {
            PyErr_Print();
        }

        Py_DECREF(pModule);
    } else {
        PyErr_Print();
    }

    // Clean up and shut down the Python interpreter
    Py_Finalize();
}


void Monitor::measure_and_write_process_bw(const std::vector<int>& processIds) {
    // Initialize the Python interpreter
    for (int pid : processIds) {
        std::cout << "monitor: pid in the processIds: " << pid << std::endl;
    }

    Py_Initialize();
    is_monitoring_bw_.store(true);
    // Ensure the interpreter started successfully
    if (!Py_IsInitialized()) {
        std::cerr << "Error: Failed to initialize Python interpreter." << std::endl;
        return;
    }

    // Add the directory containing your module to the Python path
    PyObject* sysPath = PySys_GetObject("path");
    if (!sysPath) {
        std::cerr << "Error: Failed to get Python path." << std::endl;
        Py_Finalize();
        return;
    }

    PyList_Append(sysPath, PyUnicode_FromString("../")); // Adjust as necessary

    // Import the Python module
    PyObject* pName = PyUnicode_FromString("monitoring");
    PyObject* pModule = PyImport_Import(pName);
    Py_DECREF(pName);

    if (pModule != nullptr) {
        // Get the reference to the function
        PyObject* pFunc = PyObject_GetAttrString(pModule, "run_monitor");

        if (pFunc && PyCallable_Check(pFunc)) {
            // Create a Python list for process IDs
            PyObject* pListProcessIds = PyList_New(processIds.size());
            for (size_t i = 0; i < processIds.size(); ++i) {
                PyList_SetItem(pListProcessIds, i, PyLong_FromLong(processIds[i]));
            }

            // Prepare arguments for the Python function call
            PyObject* pArgs = PyTuple_New(1);
            PyTuple_SetItem(pArgs, 0, pListProcessIds); // Tuple takes ownership

            PyObject* pGenerator = PyObject_CallObject(pFunc, pArgs); // This is now expected to be a generator

            if (pGenerator) {
                PyObject* pItem;
                while ((pItem = PyIter_Next(pGenerator)) != nullptr) {
                    if (PyDict_Check(pItem)) {
                        PyObject *key, *value;
                        Py_ssize_t pos = 0;


                        while (PyDict_Next(pItem, &pos, &key, &value)) {
                            if (PyLong_Check(key)) {
                                long pid = PyLong_AsLong(key);

                                // Assume `value` is a dictionary with 'llc', 'mbl', 'mbr'
                                PyObject* pLLC = PyDict_GetItemString(value, "llc");
                                PyObject* pMBL = PyDict_GetItemString(value, "mbl");
                                PyObject* pMBR = PyDict_GetItemString(value, "mbr");

                                if (pLLC && pMBL && pMBR) {
                                    double llc = PyFloat_AsDouble(pLLC);
                                    double mbl = PyFloat_AsDouble(pMBL);
                                    double mbr = PyFloat_AsDouble(pMBR);

//                                    std::cout << "PID: " << pid << "  llc: " << llc
//                                              << ", mbl: " << mbl << ", mbr: " << mbr << std::endl;
                                    // Get current time
//                                    std::time_t now = std::time(nullptr);
//                                    char time_str[100];
//                                    std::strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", std::localtime(&now));
//
//                                    // Save the bandwidth information to a file
//                                    std::ofstream outfile;
//                                    std::string filename = "pid_" + std::to_string(pid) + ".log";
//                                    outfile.open(filename, std::ios_base::app);
//                                    if (outfile.is_open()) {
//                                        outfile << time_str << " - llc: " << llc << ", mbl: " << mbl << ", mbr: " << mbr << std::endl;
//                                        outfile.close();
//                                    } else {
//                                        std::cerr << "Error: Could not open file " << filename << " for writing." << std::endl;
//                                    }
//

                                    auto it = pid_measured_info_map_.find(pid);
                                    if (it != pid_measured_info_map_.end()) {
                                        it->second.bw_local_measured = mbl;
                                        it->second.bw_remote_measured = mbr;
                                    } else {
                                        std::cout << "Pid " << pid << " not found in the map." << std::endl;
                                    }
                                }
                            }
                        }
                    }
                    Py_DECREF(pItem);
                }

                if (PyErr_Occurred()) PyErr_Print();
                Py_DECREF(pGenerator);
            } else {
                PyErr_Print();
                std::cerr << "Call to \"run_monitor\" did not return a generator." << std::endl;
            }

            Py_DECREF(pArgs);
        } else {
            PyErr_Print();
        }

        Py_DECREF(pModule);
    } else {
        PyErr_Print();
    }

    // Clean up and shut down the Python interpreter
    Py_Finalize();
    is_monitoring_bw_.store(false);
}

bool Monitor::monitoring_bw(){
    return is_monitoring_bw_.load();
}

// Function to call the Python function and process its return values
void print_multi_process_bw(const std::vector<int>& processIds) {
    // Initialize the Python interpreter
    Py_Initialize();

    // Ensure the interpreter started successfully
    if (!Py_IsInitialized()) {
        std::cerr << "Error: Failed to initialize Python interpreter." << std::endl;
        return;
    }

    // Add the directory containing your module to the Python path
    PyObject* sysPath = PySys_GetObject("path");
    if (!sysPath) {
        std::cerr << "Error: Failed to get Python path." << std::endl;
        Py_Finalize();
        return;
    }

    PyList_Append(sysPath, PyUnicode_FromString("../")); // Adjust as necessary

    // Import the Python module
    PyObject* pName = PyUnicode_FromString("monitoring");
    PyObject* pModule = PyImport_Import(pName);
    Py_DECREF(pName);

    if (pModule != nullptr) {
        // Get the reference to the function
        PyObject* pFunc = PyObject_GetAttrString(pModule, "run_monitor");

        if (pFunc && PyCallable_Check(pFunc)) {
            // Create a Python list for process IDs
            PyObject* pListProcessIds = PyList_New(processIds.size());
            for (size_t i = 0; i < processIds.size(); ++i) {
                PyList_SetItem(pListProcessIds, i, PyLong_FromLong(processIds[i]));
            }

            // Prepare arguments for the Python function call
            PyObject* pArgs = PyTuple_New(1);
            PyTuple_SetItem(pArgs, 0, pListProcessIds); // Tuple takes ownership

            PyObject* pGenerator = PyObject_CallObject(pFunc, pArgs); // This is now expected to be a generator

            if (pGenerator) {
                PyObject* pItem;
                while ((pItem = PyIter_Next(pGenerator)) != nullptr) {
                    if (PyDict_Check(pItem)) {
                        PyObject *key, *value;
                        Py_ssize_t pos = 0;

                        while (PyDict_Next(pItem, &pos, &key, &value)) {
                            if (PyLong_Check(key)) {
                                long pid = PyLong_AsLong(key);
                                // Assume `value` is a dictionary with 'llc', 'mbl', 'mbr'
                                PyObject* pLLC = PyDict_GetItemString(value, "llc");
                                PyObject* pMBL = PyDict_GetItemString(value, "mbl");
                                PyObject* pMBR = PyDict_GetItemString(value, "mbr");

                                if (pLLC && pMBL && pMBR) {
                                    double llc = PyFloat_AsDouble(pLLC);
                                    double mbl = PyFloat_AsDouble(pMBL);
                                    double mbr = PyFloat_AsDouble(pMBR);

                                    std::cout << "PID: " << pid << "  llc: " << llc
                                              << ", mbl: " << mbl << ", mbr: " << mbr << std::endl;
                                }
                            }
                        }
                    }
                    Py_DECREF(pItem);
                }

                if (PyErr_Occurred()) PyErr_Print();
                Py_DECREF(pGenerator);
            } else {
                PyErr_Print();
                std::cerr << "Call to \"run_monitor\" did not return a generator." << std::endl;
            }

            Py_DECREF(pArgs);
        } else {
            PyErr_Print();
        }

        Py_DECREF(pModule);
    } else {
        PyErr_Print();
    }

    // Clean up and shut down the Python interpreter
    Py_Finalize();
}

BandwidthData detect_process_bw(int processId) {
    // Initialize default values for the return struct
    BandwidthData bwData = {-1.0, -1.0, -1.0};

    // Initialize the Python interpreter
    Py_Initialize();

    // Ensure the interpreter started successfully
    if (!Py_IsInitialized()) {
        std::cerr << "Error: Failed to initialize Python interpreter." << std::endl;
        return bwData;
    }

    // Add the directory containing your module to the Python path
    PyObject* sysPath = PySys_GetObject("path");
    if (!sysPath) {
        std::cerr << "Error: Failed to get Python path." << std::endl;
        Py_Finalize();
        return bwData;
    }

    PyList_Append(sysPath, PyUnicode_FromString("../")); // Adjust as necessary

    // Import the Python module
    PyObject* pName = PyUnicode_FromString("monitoring");
    PyObject* pModule = PyImport_Import(pName);
    Py_DECREF(pName);

    if (pModule != nullptr) {
        // Get the reference to the function
        PyObject* pFunc = PyObject_GetAttrString(pModule, "run_monitor");

        if (pFunc && PyCallable_Check(pFunc)) {
            PyObject* pArgs = PyTuple_New(1);
            PyObject* pValueProcessId = PyLong_FromLong(processId);
            PyTuple_SetItem(pArgs, 0, pValueProcessId);

            PyObject* pGenerator = PyObject_CallObject(pFunc, pArgs); // This is now expected to be a generator

            if (pGenerator) {
                PyObject* pItem;
                int count = 0;
                while ((pItem = PyIter_Next(pGenerator)) != nullptr) {
                    if (PyDict_Check(pItem)) {
                        PyObject* pLLC = PyDict_GetItemString(pItem, "llc");
                        PyObject* pMBL = PyDict_GetItemString(pItem, "mbl");
                        PyObject* pMBR = PyDict_GetItemString(pItem, "mbr");

                        if (pLLC && pMBL && pMBR) {
                            bwData.llc = PyFloat_AsDouble(pLLC);
                            bwData.mbl = PyFloat_AsDouble(pMBL);
                            bwData.mbr = PyFloat_AsDouble(pMBR);

                            // Use the data as needed
                            // std::cout << "llc: " << llc << " mbl: " << mbl << " mbr: " << mbr << std::endl;
                        }
                        Py_DECREF(pItem); // Avoid memory leak
                        if (count == 3){ // the first time is not accurate
                            break;
                        } else {
                            count ++;
                        }
                    }
                }

                if (PyErr_Occurred()) {
                    PyErr_Print(); // Handle any errors that occurred in the iterator
                }

                Py_DECREF(pGenerator);
            } else {
                PyErr_Print();
                std::cerr << "Call to \"run_monitor\" did not return a generator." << std::endl;
            }

            Py_DECREF(pArgs);
        } else {
            PyErr_Print();
        }

        Py_DECREF(pModule);
    } else {
        PyErr_Print();
    }

    // Clean up and shut down the Python interpreter
    Py_Finalize();
    return bwData;
}


/*
int main (int argc, char *argv[]) {
    ////Monitor src = Monitor();        // moved to global to make signal handler work
    ////std::vector<int> cores = {0};       // moved to global to make signal handler work

    for (int i = 0; i < NUM_CORES; i++) {
        cores_g.push_back(i);
    }

    int processId = -1; // Default to an invalid process ID
    std::vector<int> pids; // Store multiple PIDs for bw mode
    std::string processName = "";
    std::string mode = "";

    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--mode" && i + 1 < argc) {
            mode = argv[i + 1];
            i++; // Skip the mode value
        } else if (std::string(argv[i]) == "--pid" && i + 1 < argc) {
            // In bw mode, allow multiple PIDs

            while (i + 1 < argc && argv[i + 1][0] != '-') {
                int pid = std::atoi(argv[i + 1]);
                pids.push_back(pid);
                i++;
            }
            if (!pids.empty()) {
                std::cout << "PIDs: ";
                for (int pid: pids) std::cout << pid << " ";
                std::cout << std::endl;
            }


        } else if (std::string(argv[i]) == "--pname" && i + 1 < argc) {
            processName = argv[i + 1];
            std::cout << "Process Name: " << processName << std::endl;
            i++; // Skip the process name value
        }
        // Add more conditions as necessary
    }

    // After parsing all arguments, act based on the mode
    if (mode == "la") {
        if (!pids.empty()) {
            // For simplicity, we're using only the first PID in latency mode
            monitor.measure_process_latency(pids.front());
        } else if (!processName.empty()) {
            monitor.measure_process_latency(processName);
        } else {
            std::cerr << "No valid process identifier provided." << std::endl;
            return 1;
        }
    } else if (mode == "bw") {
        if (!pids.empty()) {
            // Here, you would iterate over pids and monitor each
            print_multi_process_bw(pids);
        } else if (!processName.empty()) {
            // Get PID from process name and monitor it
            int pid = monitor.get_pid_from_proc_name(processName);
            print_process_bw(pid);
        } else {
            std::cerr << "Error: Process ID(s) not provided." << std::endl;
            return 1;
        }
    } else {
        std::cerr << "Error: No valid mode (la or bw) identifier provided." << std::endl;
        return 1;
    }

    return 0;



    // src.measure_process_latency("memtier_benchmark");
    //src.measure_process_latency("redis-server");
    //src.measure_process_latency("bc");


}
*/

#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cctype>
#include <algorithm>  // Include this for std::max
#include <dirent.h>
#include <thread>
#define CG_ROOT_DIR "/sys/fs/cgroup"
#include <sstream>
#include "monitor.h"
#include <unistd.h>
#include <atomic>
#include <csignal>


class Profiler{

public:
    Profiler(std::string process_name, int cg_idx, uint64_t local_memory_limit);
    void profiling();
    void profiling_concise(int cg_idx, std::string process_name);
    void start_profiling(int cg_idx, uint64_t init_memory_limit);
    void start_profiling();
    void save_la_to_monitor(pid_t pid);
    double read_la_from_monitor(pid_t pid);
    double get_latency_of_process(pid_t pid);
    void start_profiling_memory_only();
    void start_profiling_concise_memory_only(int cg_idx, std::string process_name);
    static void signal_handler(int signal); // Static signal handler
    void write_results_to_csv(const std::string& filename);
    void start_profiling_no_mercury();
    void save_bw_to_monitor_and_file(std::vector<int> process_ids);
    void profiling_no_mercury(std::string process_name);
    void save_la_to_monitor_and_file(pid_t pid, std::string app_name);



    struct ProfilingData {
        std::string timestamp;
        uint64_t memory_limit;
        std::map<uint64_t, std::pair<uint64_t, uint64_t>> memory_values; // Maps PID -> (Node0, Node1)
    };





private:
    uint64_t local_memory_limit_;
    uint64_t max_local_memory_limit_;
    pid_t target_pid_;
    int cg_idx_;
    uint64_t max_app_total_memory_;
    std::string process_name_;
    Monitor monitor_;
    std::vector<uint64_t> all_pids_;
    std::vector<ProfilingData> all_profiling_data_;
    // Declare a global atomic flag to signal when to write results
    static std::atomic<bool> write_results_flag; // Static flag for signal






};

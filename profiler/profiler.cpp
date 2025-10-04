#include "profiler.h"

// Define and initialize the static member variable
std::atomic<bool> Profiler::write_results_flag{false};

// Function to print the usage of the program
void print_usage(const std::string& program_name) {
    std::cerr << "Usage: " << program_name
              << " [-cg_idx <index>] [-mem_limit_str <limit>] [-mem_limit_value <bytes>]\n"
              << "                  [-process_name <name>] [-memory_only] [-concise_memory_only]\n"
              << "                  [-memory_with_latency_no_mercury]\n\n"
              << "Options:\n"
              << "  -cg_idx <index>               Specify the cgroup index. Required unless using -memory_with_latency_no_mercury.\n"
              << "  -mem_limit_str <limit>        Set memory limit as a string (e.g., 20G).\n"
              << "  -mem_limit_value <bytes>      Set memory limit as a numeric value in bytes.\n"
              << "  -process_name <name>          Specify the name of the process to monitor.\n"
              << "  -memory_only                  Run profiling for memory usage only.\n"
              << "  -concise_memory_only          Run concise memory profiling without detailed latency.\n"
              << "  -memory_with_latency_no_mercury  Run memory and latency profiling without Mercury (cg_idx not required).\n\n"
              << "Examples:\n"
              << "  " << program_name << " -cg_idx 1 -mem_limit_str 20G -process_name llama -memory_only\n"
              << "  " << program_name << " -cg_idx 2 -mem_limit_value 2147483648 -process_name llama\n"
              << "  " << program_name << " -process_name llama -memory_with_latency_no_mercury\n";
}


// Signal handler
void Profiler::signal_handler(int signal) {
    if (signal == SIGUSR1) {
        write_results_flag = true; // Set the flag when SIGUSR1 is received
        std::cout<< "receive the signal in the profiler" << std::endl;
    }
}


// Function to update memory limit by writing the string directly to the file (e.g., "20G")
void update_memory_limit_string(const std::string &limit_str, int cg_idx) {
    std::string cg_base_dir = "/sys/fs/cgroup/cg";
    std::string memcg_filename = cg_base_dir + std::to_string(cg_idx) + "/memory.per_numa_high";
    std::ofstream memcg_file;

    memcg_file.open(memcg_filename, std::ios::trunc);
    if (!memcg_file) {
        std::cout << "Error opening file " << memcg_filename << ". Exiting." << std::endl;
        exit(1);
    }

    // Write the limit string (e.g., 20G) and "max" to the file
    std::string content = "max\n" + limit_str + "\n";
    memcg_file << content;
    memcg_file.close();
}

// Function to update memory limit by writing the numeric value directly to the file
void update_memory_limit_value(uint64_t limit, int cg_idx) {
    std::string cg_base_dir = "/sys/fs/cgroup/cg";
    std::string memcg_filename = cg_base_dir + std::to_string(cg_idx) + "/memory.per_numa_high";
    std::ofstream memcg_file;

    memcg_file.open(memcg_filename, std::ios::trunc);
    if (!memcg_file) {
        std::cout << "Error opening file " << memcg_filename << ". Exiting." << std::endl;
        exit(1);
    }

    // Write the numeric value and "max" to the file
    std::string content = "max\n" + std::to_string(limit) + "\n";
    memcg_file << content;
    memcg_file.close();
}

//// this is the avg latency value
//double Profiler::get_latency_of_process(pid_t pid) {
//    const int numReadings = 3;  // Number of valid readings to take
//    double total_latency = 0.0;
//    int valid_readings = 0;
//
//    while (valid_readings < numReadings) {
//        double latency = read_la_from_monitor(pid);
//
//        if (std::isnan(latency)) {
//            std::cout << "Read latency is NaN, skipping this value." << std::endl;
//        } else {
//            total_latency += latency;
//            ++valid_readings;
//            std::cout << "Valid latency reading: " << latency << std::endl;
//        }
//
//        sleep_ms(200);  // Sleep for 0.2 second before the next reading
//    }
//
//    double avg_latency = total_latency / numReadings;
//    std::cout << "Average latency after " << numReadings << " valid readings: " << avg_latency << std::endl;
//    return avg_latency;
//}

pid_t get_pid_based_on_cmdline_name(const std::string& proc_name) {
    pid_t target_pid = -1;
    long max_memory = 0;
    bool found = false; // Initialize the flag to false

    // Open the /proc directory to iterate over all processes
    DIR* proc_dir = opendir("/proc");
    if (!proc_dir) {
        std::cerr << "Failed to open /proc directory." << std::endl;
        return -1;
    }

    struct dirent* entry;
    while ((entry = readdir(proc_dir)) != nullptr) {
        // Check if the directory name is a number (indicating a PID)
        if (!isdigit(entry->d_name[0])) {
            continue;
        }

        std::string pid = entry->d_name;

        // Construct the /proc/[PID]/cmdline path to read the full command line
        std::string cmdline_path = "/proc/" + pid + "/cmdline";
        std::ifstream cmdline_file(cmdline_path);
        if (!cmdline_file.is_open()) {
            continue;
        }

        // Read the full command line, which is stored as a null-separated string
        std::string cmdline, arg;
        while (std::getline(cmdline_file, arg, '\0')) {
            cmdline += arg + " "; // Combine arguments with spaces for easier matching
        }
        cmdline_file.close();

        // Check if the command line contains the target name (partial match)
        if (cmdline.find(proc_name) == std::string::npos) {
            continue; // Skip processes that don't match
        }

        found = true; // Process name found

        // Construct the /proc/[PID]/status path to read memory info
        std::string status_path = "/proc/" + pid + "/status";
        std::ifstream status_file(status_path);
        if (!status_file.is_open()) {
            continue;
        }

        std::string line;
        long current_memory = 0;
        while (std::getline(status_file, line)) {
            // Check the VmRSS field for memory usage (in kB)
            if (line.find("VmRSS:") == 0) {
                std::istringstream iss(line);
                std::string key;
                iss >> key >> current_memory;
                break;
            }
        }

        status_file.close();

        // If this process has higher memory usage, update the target PID
        if (current_memory > max_memory) {
            max_memory = current_memory;
            target_pid = std::stoi(pid);
        }
    }

    closedir(proc_dir);

    if (!found) {
        std::cout << "Did not find the process" << std::endl;
    } else {
        std::cout << "Found the process" << std::endl;
    }

    // Return the PID with the highest memory usage or -1 if not found
    return target_pid;
}



std::pair<uint64_t, uint64_t> get_local_and_total_memory(int cg_idx) {
    uint64_t total_app_memory = 0;
    uint64_t top_tier_memory_anon_N1 = 0;
    uint64_t top_tier_app_memory = 0;
    uint64_t top_tier_memory_file_N1 = 0;
    std::string cg_base_dir = CG_ROOT_DIR; // Assuming CG_ROOT_DIR is defined somewhere
    cg_base_dir += "/cg";
    std::string memcg_filename = cg_base_dir + std::to_string(cg_idx) + "/memory.numa_stat";

    std::ifstream file(memcg_filename);
    std::string line;

    if (!file.is_open()) {
        std::cerr << "Failed to open file: " << memcg_filename << std::endl;
        return {-1,-1};
    }

    while (std::getline(file, line)) {
        std::istringstream iss(line);
        std::string key;
        iss >> key; // Extract the key (e.g., "anon" or "file")

        if (key == "anon" || key == "file") {
            std::string token;
            while (iss >> token) {
                size_t pos = token.find('=');
                if (pos != std::string::npos) {
                    std::string prefix = token.substr(0, pos);
                    uint64_t value = std::stod(token.substr(pos + 1)); // Convert string to double
                    total_app_memory += value; // Add to total capacity
                    if (prefix == "N1") {
                        if (key == "anon") {
                            top_tier_memory_anon_N1 = value; // Store specifically for anon N1
                        } else if (key == "file") {
                            top_tier_memory_file_N1 = value; // Store specifically for file N1
                        }
                    }
                }
            }
        }
    }

    file.close();

    top_tier_app_memory = top_tier_memory_anon_N1 + top_tier_memory_file_N1;
//    std::cout<<"total app memory: "<<total_app_memory<< ",  top_tier app memory: " << top_tier_app_memory <<std::endl;
    // At this point, memory_total_capacity contains the sum of all relevant numbers
    uint64_t tolerance = 2ULL * 1024 * 1024 * 1024; // 2GB
    return {top_tier_app_memory, total_app_memory};

}

Profiler::Profiler(std::string process_name, int cg_idx, uint64_t local_memory_limit){
    // Additional initialization code can go here if needed
    process_name_ = process_name;
    cg_idx_ = cg_idx;
    local_memory_limit_ = local_memory_limit;
    // Set up the signal handler
    std::signal(SIGUSR1, signal_handler);
}

void Profiler::save_la_to_monitor(pid_t pid){
    std::cout<<"start monitoring latency " << std::endl;
    monitor_.measure_and_write_process_latency(pid);
}
void Profiler::save_la_to_monitor_and_file(pid_t pid, std::string app_name){
    std::cout<<"start monitoring latency " << std::endl;
    monitor_.measure_and_write_process_latency_to_file(pid, app_name);
}

void Profiler::save_bw_to_monitor_and_file(std::vector<int> process_ids){
    std::cout<<"start monitoring bandwidth " << std::endl;
    monitor_.measure_and_write_process_bw_to_file(process_ids);
//    std::cout<<"monitoring bandwidth succeeds" << std::endl;
}

double Profiler::read_la_from_monitor(pid_t pid){
    return monitor_.read_process_latency(pid);

}

//void Profiler::start_profiling(int cg_idx, uint64_t init_memory_limit){
//    local_memory_limit_ = init_memory_limit;
//    // read and set the memory limit for the workload
//    update_memory_limit_value(local_memory_limit_, cg_idx);
//
//    target_pid_ = get_pid_based_on_cmdline_name(process_name_);
//    monitor_.add_pid(target_pid_,cg_idx);
//    // store the access memory latency
//
//    while (true){ //TODO change this to 'while app is running'
//        profiling(cg_idx);
//
//    }
//}

void Profiler::start_profiling(){
    update_memory_limit_value(local_memory_limit_, cg_idx_);
    target_pid_ = get_pid_based_on_cmdline_name(process_name_);
    std::cout<<"target pid is: " << target_pid_ << std::endl;
    std::cout<<"process name is: " << process_name_ << std::endl;
    monitor_.add_pid(target_pid_,cg_idx_, process_name_);
    // store the access memory latency
    std::thread la_monitor_thread(&Profiler::save_la_to_monitor, this, target_pid_);
    la_monitor_thread.detach();  // Detach to let it run independently
    std::cout<<"start to monitor the memory usage" << std::endl;

    while (true){
        profiling();
        sleep(1);
        // Check if the signal to write results was received
        if (write_results_flag) {
            write_results_to_csv("memory_numastat_log.csv");
            std::cout << "Received signal to write results. Exiting..." << std::endl;
            break;
        }
    }
}

void Profiler::start_profiling_no_mercury(){

    target_pid_ = get_pid_based_on_cmdline_name(process_name_);
    std::cout<<"target pid is: " << target_pid_ << std::endl;
    std::cout<<"process name is: " << process_name_ << std::endl;
    monitor_.add_pid(target_pid_,cg_idx_, process_name_);
    // store the access memory latency
    std::thread la_monitor_thread(&Profiler::save_la_to_monitor_and_file, this, target_pid_, process_name_);
    la_monitor_thread.detach();  // Detach to let it run independently
    std::cout<<"start to monitor the memory usage" << std::endl;

    std::vector<int> processIds;
    processIds.push_back(target_pid_);
    std::cout<<"start to monitor the bandwidth usage" << std::endl;
    if (process_name_ == "llama"){
        std::thread bwMonitorThread_1(&Profiler::save_bw_to_monitor_and_file, this, processIds);
        // Detaching the thread allows the main thread to continue without waiting for laMonitorThread to finish.
        bwMonitorThread_1.detach();
    }
    while (true){ //TODO change this to 'while app is running'
        profiling_no_mercury(process_name_);
        sleep(1);
    }
}

void Profiler::start_profiling_memory_only(){
    // read and set the memory limit for the workload
    update_memory_limit_value(local_memory_limit_, cg_idx_);
    target_pid_ = get_pid_based_on_cmdline_name(process_name_);
    monitor_.add_pid(target_pid_,cg_idx_, process_name_);
    // store the access memory latency
//    std::thread la_monitor_thread(&Profiler::save_la_to_monitor, this, target_pid_);
//    la_monitor_thread.detach();  // Detach to let it run independently
    std::cout<<"start to monitor the memory usage" << std::endl;

    while (true){ //TODO change this to 'while app is running'
        profiling();
        sleep(1);
        // TODO: make the file name have app name
        // Check if the signal to write results was received
        if (write_results_flag) {
            write_results_to_csv("memory_numastat_log.csv");
            std::cout << "Received signal to write results. Exiting..." << std::endl;
            break;
        }
    }

}

void Profiler::start_profiling_concise_memory_only(int cg_idx, std::string process_name){
    // read and set the memory limit for the workload
    std::cout<<"start to monitor the memory usage" << std::endl;

    while (true){ //TODO change this to 'while app is running'
        profiling_concise(cg_idx,process_name);
        sleep(1);
    }
}

std::string executeCommand(const std::string& command) {
    std::string result;
    char buffer[128];
    FILE* pipe = popen(command.c_str(), "r");
    if (!pipe) {
        std::cerr << "Failed to open pipe for command: " << command << std::endl;
        return result;
    }
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        result += buffer;
    }
    pclose(pipe);
    return result;
}

std::pair<uint64_t, uint64_t> parseNumastatOutput_concise(const std::string& output) {
    std::istringstream stream(output);
    std::string line;
    uint64_t totalNode0 = 0, totalNode1 = 0;

    while (std::getline(stream, line)) {
        // Look for the line that starts with "Total"
        if (line.find("Total") == 0) {
            std::istringstream iss(line);
            std::string temp;
            double node0 = 0.0, node1 = 0.0;

            // Read and discard the "Total" label
            iss >> temp;

            // Read values for Node 0 and Node 1, handling potential extra spaces
            if (std::getline(iss >> std::ws, temp, ' ') && !temp.empty()) {
                node0 = std::stod(temp);
            }
            if (std::getline(iss >> std::ws, temp, ' ') && !temp.empty()) {
                node1 = std::stod(temp);
            }

            // Convert from MB to B by multiplying by 1024 * 1024
             totalNode0 = static_cast<uint64_t>(node0 * 1024 * 1024);
             totalNode1 = static_cast<uint64_t>(node1 * 1024 * 1024);

            break;  // Only read the first "Total" line
        }
    }

    return {totalNode0, totalNode1};

}

std::map<uint64_t, std::pair<uint64_t, uint64_t>> parseNumastatOutput(const std::string& output) {
    std::istringstream stream(output);
    std::string line;
    std::map<uint64_t, std::pair<uint64_t, uint64_t>> pidNodeMemory;

    while (std::getline(stream, line)) {
        std::istringstream iss(line);
        uint64_t pid = 0;
        std::string processName;
        double node0 = 0.0, node1 = 0.0;

        // Check if the line contains memory usage data (lines with PID and Node data)
        if (std::isdigit(line[0])) {
            iss >> pid;  // Extract the PID
            iss >> processName;  // Extract the process name (e.g., "(node)")

            // Extract memory values for Node 0 and Node 1
            std::string temp;
            if (std::getline(iss >> std::ws, temp, ' ') && !temp.empty()) {
                node0 = std::stod(temp);
            }
            if (std::getline(iss >> std::ws, temp, ' ') && !temp.empty()) {
                node1 = std::stod(temp);
            }

            // Convert from MB to B and store in the map
            pidNodeMemory[pid] = {
                    static_cast<uint64_t>(node0 * 1024 * 1024),
                    static_cast<uint64_t>(node1 * 1024 * 1024)
            };
        }
    }

    return pidNodeMemory;
}


std::pair<uint64_t, uint64_t> getProcessMemory_concise(const std::string& process_name) {
    std::string command = "numastat -p " + process_name;
    std::string output = executeCommand(command);
    uint64_t app_total_memory;
    uint64_t app_local_memory;
//    std::cout<<output<<std::endl;
    if (!output.empty()) {
        auto memoryInfo = parseNumastatOutput_concise(output);
        app_total_memory = memoryInfo.first + memoryInfo.second;
        app_local_memory = memoryInfo.second;
        return {app_local_memory, app_total_memory };
    } else {
        std::cerr << "No output from numastat command." << std::endl;
    }
    return {app_local_memory, app_total_memory};
}

std::map<uint64_t, std::pair<uint64_t, uint64_t>> getProcessMemory(const std::string& process_name) {
    std::string command = "numastat -p " + process_name;
    std::string output = executeCommand(command);

    // Return memory information for all PIDs
    if (!output.empty()) {
        return parseNumastatOutput(output);
    } else {
        std::cerr << "No output from numastat command." << std::endl;
    }
    return {};
}



// Function to read the memory limit from memory.per_numa_high
uint64_t get_memory_limit(int cg_idx) {
    std::string cg_base_dir = "/sys/fs/cgroup/cg";
    std::string memory_limit_filename = cg_base_dir + std::to_string(cg_idx) + "/memory.per_numa_high";

    std::ifstream mem_limit_file(memory_limit_filename);
    if (!mem_limit_file.is_open()) {
        std::cerr << "Failed to open file: " << memory_limit_filename << std::endl;
        return 0;
    }

    std::string line;
    // Skip the first line ("max")
    std::getline(mem_limit_file, line);
    // Read the second line, which contains the memory limit
    std::getline(mem_limit_file, line);

    mem_limit_file.close();
    return std::stoull(line);  // Convert the string to a number
}

void Profiler::profiling_concise(int cg_idx, std::string process_name){
    uint64_t current_app_total_memory;
    uint64_t current_app_local_memory;

    // Read and set the memory limit for the workload
    auto memory_values = getProcessMemory_concise(process_name);
    current_app_local_memory = memory_values.first;
    current_app_total_memory = memory_values.second;


    std::string file_name = "memory_numastat_concise_"+ process_name +"_log.csv";
    // Open or create the CSV file in append mode
    std::ofstream memory_file(file_name, std::ios_base::app);

    // Get the memory limit
    uint64_t memory_limit = get_memory_limit(cg_idx);

    if (memory_file.is_open()) {
        // Check if the file is empty, and if so, write the header row
        memory_file.seekp(0, std::ios::end);
        if (memory_file.tellp() == 0) {
            memory_file << "Timestamp,App Total Memory (bytes),App Local Memory (bytes),Memory_Limit\n";
        }

        // Get the current time
        auto now = std::chrono::system_clock::now();
        std::time_t now_time = std::chrono::system_clock::to_time_t(now);

        // Write the data in CSV format
        memory_file << std::put_time(std::localtime(&now_time), "%Y-%m-%d %H:%M:%S") << ","
                    << current_app_total_memory << ","
                    << current_app_local_memory << ","
                    << memory_limit << "\n";

        memory_file.close();
    }
}

void Profiler::profiling_no_mercury(std::string process_name){
    uint64_t current_app_total_memory;
    uint64_t current_app_local_memory;

    // Read and set the memory limit for the workload
    auto memory_values = getProcessMemory_concise(process_name);
    current_app_local_memory = memory_values.first;
    current_app_total_memory = memory_values.second;


    std::string file_name = "memory_numastat_concise_"+ process_name +"_log.csv";
    // Open or create the CSV file in append mode
    std::ofstream memory_file(file_name, std::ios_base::app);


    if (memory_file.is_open()) {
        // Check if the file is empty, and if so, write the header row
        memory_file.seekp(0, std::ios::end);
        if (memory_file.tellp() == 0) {
            memory_file << "Timestamp,App Total Memory (bytes),App Local Memory (bytes)\n";
        }

        // Get the current time
        auto now = std::chrono::system_clock::now();
        std::time_t now_time = std::chrono::system_clock::to_time_t(now);

        // Write the data in CSV format
        memory_file << std::put_time(std::localtime(&now_time), "%Y-%m-%d %H:%M:%S") << ","
                    << current_app_total_memory << ","
                    << current_app_local_memory << "\n";

        memory_file.close();
    }
}

void Profiler::write_results_to_csv(const std::string& filename) {
    std::ofstream memory_file(filename);

    if (memory_file.is_open()) {
        // Write the header
        memory_file << "Timestamp,Memory_Limit,Total_Memory";
        for (const auto pid : all_pids_) {
            memory_file << ",PID_" << pid << "_Node0,PID_" << pid << "_Node1,PID_" << pid << "_Total";
        }
        memory_file << "\n";

        // Write the data rows
        for (const auto& data : all_profiling_data_) {
            memory_file << data.timestamp << "," << data.memory_limit;

            // Compute total memory for all PIDs
            uint64_t total_memory = 0;
            for (const auto pid : all_pids_) {
                if (data.memory_values.find(pid) != data.memory_values.end()) {
                    const auto& memory = data.memory_values.at(pid);
                    total_memory += (memory.first + memory.second);
                }
            }

            // Write total memory to the file
            memory_file << "," << total_memory;

            // Write memory usage for each PID
            for (const auto pid : all_pids_) {
                if (data.memory_values.find(pid) != data.memory_values.end()) {
                    const auto& memory = data.memory_values.at(pid);
                    memory_file << "," << memory.first << "," << memory.second << "," << (memory.first + memory.second);
                } else {
                    memory_file << ",0,0,0"; // Write 0 for missing PIDs
                }
            }
            memory_file << "\n";
        }

        memory_file.close();
    } else {
        std::cerr << "Error: Unable to open " << filename << " for writing." << std::endl;
    }
}




void Profiler::profiling() {
    // Maximum number of retry attempts
    const int max_retries = 10;
    int attempt = 0;
    std::map<uint64_t, std::pair<uint64_t, uint64_t>> memory_values;

    // Retry fetching memory values until valid or max attempts reached
    while (attempt < max_retries) {
        memory_values = getProcessMemory(process_name_);
        if (!memory_values.empty()) {
            break; // Successfully fetched memory values
        }
        std::cerr << "Warning: Failed to fetch memory values. Retrying... (" << (attempt + 1) << "/" << max_retries << ")" << std::endl;
        attempt++;
    }
    if (memory_values.empty()) {
        std::cerr << "Error: Failed to fetch memory values after " << max_retries << " attempts. Skipping this profiling step." << std::endl;
        return; // Abort profiling if memory values are invalid
    }

    // Update the list of all seen PIDs while preserving order
    for (const auto& [pid, _] : memory_values) {
        if (std::find(all_pids_.begin(), all_pids_.end(), pid) == all_pids_.end()) {
            all_pids_.push_back(pid); // Add new PID to the end
        }
    }

    uint64_t memory_limit = get_memory_limit(cg_idx_);

    // Get the current time
    auto now = std::chrono::system_clock::now();
    std::time_t now_time = std::chrono::system_clock::to_time_t(now);
    std::ostringstream oss;
    oss << std::put_time(std::localtime(&now_time), "%Y-%m-%d %H:%M:%S");
    std::string timestamp = oss.str();


    // Store the results in the structure
    all_profiling_data_.push_back({timestamp, memory_limit, memory_values});
}





int main(int argc, char *argv[]) {

//    if (argc != 2) {
//        std::cerr << "Usage: " << argv[0] << " <process_name>" << std::endl;
//        return 1;
//    }
//
//    printMemoryUsage(argv[1]);
//    return 0;

    int cg_idx = -1;
    std::string limit_str;
    uint64_t limit_value = 0;
    bool use_string_limit = false;
    std::string process_name;
    bool memory_only = false;
    bool concise_memory_only = false;
    bool memory_with_latency_no_mercury = false;
    const char* pipe_path = "/tmp/profiler_pipe";

    const char* pid_file_path = "/tmp/profiler_pid";

    // Write the PID to a file
    std::ofstream pid_file(pid_file_path);
    if (pid_file.is_open()) {
        pid_file << getpid() << std::endl;
        pid_file.close();
    } else {
        std::cerr << "Failed to open PID file for writing." << std::endl;
        return 1;
    }

    std::cout << "Profiler PID: " << getpid() << std::endl;





    // Parse arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if (arg == "-cg_idx" && i + 1 < argc) {
            cg_idx = std::stoi(argv[++i]);  // Parse the next argument as cgroup index
        } else if (arg == "-mem_limit_str" && i + 1 < argc) {
            limit_str = argv[++i];  // Parse the next argument as memory limit string (e.g., 20G)
            use_string_limit = true;  // We will use the string limit format
        } else if (arg == "-mem_limit_value" && i + 1 < argc) {
            limit_value = std::stoull(argv[++i]);  // Parse the next argument as memory limit (numeric)
        } else if (arg == "-process_name" && i + 1 < argc) {
            process_name = argv[++i];
        } else if (arg == "-memory_only") {
            memory_only = true;
        } else if (arg == "-concise_memory_only") {
            concise_memory_only = true;
        } else if (arg == "-memory_with_latency_no_mercury") {
            memory_with_latency_no_mercury = true;
        }

        else {
            print_usage(argv[0]);
            return 1;
        }
    }

//    // Check if cg_idx is valid
//    if (cg_idx == -1) {
//        print_usage(argv[0]);
//        return 1;
//    }

    // Check if we are using a string limit or a numeric limit
    if (use_string_limit) {
        // Call the function to update the memory limit with a string
        update_memory_limit_string(limit_str, cg_idx);
        std::cout << "Memory limit updated successfully for cgroup " << cg_idx << " with limit " << limit_str << std::endl;
    } else if (limit_value > 0) {
        // Call the function to update the memory limit with a numeric value
        if (memory_only){
            Profiler profiler = Profiler(process_name, cg_idx, limit_value);
            profiler.start_profiling_memory_only();
            std::cout << "Memory limit updated successfully for cgroup " << cg_idx << " with limit " << limit_value << " bytes" << std::endl;
        } else if (concise_memory_only){
            Profiler profiler = Profiler(process_name, cg_idx, limit_value);
            profiler.start_profiling_concise_memory_only(cg_idx, process_name);

        }
        else {
            Profiler profiler = Profiler(process_name, cg_idx, limit_value);
            profiler.start_profiling();
            std::cout << "Memory limit updated successfully for cgroup " << cg_idx << " with limit " << limit_value << " bytes" << std::endl;
        }
    } else {
        if (memory_with_latency_no_mercury){
            Profiler profiler = Profiler(process_name, -1, -1); // so for this one, the experiment does not run on mercury
            profiler.start_profiling_no_mercury();
        }
        else {
            print_usage(argv[0]);
            return 1;
        }

    }

    return 0;
}

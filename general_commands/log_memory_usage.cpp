#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <ctime>
#include <vector>
#include <sys/stat.h>
#include <unistd.h>

// Function to read top-tier and total memory from memory.numa_stat
std::pair<uint64_t, uint64_t> get_local_and_total_memory(int cg_idx) {
    uint64_t total_app_memory = 0;
    uint64_t top_tier_memory_anon_N1 = 0;
    uint64_t top_tier_app_memory = 0;
    uint64_t top_tier_memory_file_N1 = 0;

    std::string cg_base_dir = "/sys/fs/cgroup/cg";
    std::string memcg_filename = cg_base_dir + std::to_string(cg_idx) + "/memory.numa_stat";

    std::ifstream file(memcg_filename);
    if (!file.is_open()) {
        std::cerr << "Failed to open file: " << memcg_filename << std::endl;
        return {-1, -1};
    }

    std::string line;
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
                    uint64_t value = std::stoull(token.substr(pos + 1));
                    total_app_memory += value; // Add to total capacity
                    if (prefix == "N1") {
                        if (key == "anon") {
                            top_tier_memory_anon_N1 = value; // Store anon N1 memory
                        } else if (key == "file") {
                            top_tier_memory_file_N1 = value; // Store file N1 memory
                        }
                    }
                }
            }
        }
    }

    file.close();
    top_tier_app_memory = top_tier_memory_anon_N1 + top_tier_memory_file_N1;
    return {top_tier_app_memory, total_app_memory};
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

// Function to get the current time as a string
std::string get_current_time() {
    time_t now = time(0);
    tm *ltm = localtime(&now);

    char buffer[80];
    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", ltm);
    return std::string(buffer);
}

// Function to check if a directory exists
bool directory_exists(const std::string &dir_path) {
    struct stat info;
    return (stat(dir_path.c_str(), &info) == 0 && (info.st_mode & S_IFDIR));
}

// Function to create a directory
void create_directory(const std::string &dir_path) {
    std::string command = "mkdir -p " + dir_path;
    system(command.c_str());
}

// Function to check if a file exists
bool file_exists(const std::string& filename) {
    struct stat buffer;
    return (stat(filename.c_str(), &buffer) == 0);
}

// Function to log memory data
void log_memory_data(int cg_idx, const std::string &output_dir, const std::string &output_file = "memory_usage_log.csv") {
    // Get the memory data
    std::pair<uint64_t, uint64_t> memory_data = get_local_and_total_memory(cg_idx);
    uint64_t top_tier_memory = memory_data.first;
    uint64_t total_memory = memory_data.second;

    // Get the memory limit
    uint64_t memory_limit = get_memory_limit(cg_idx);

    if (top_tier_memory == static_cast<uint64_t>(-1) || total_memory == static_cast<uint64_t>(-1)) {
        std::cerr << "Error fetching memory data." << std::endl;
        return;
    }

    // Get current time
    std::string current_time = get_current_time();

    // Check if output directory exists, if not, create it
    if (!directory_exists(output_dir)) {
        create_directory(output_dir);
    }

    // Define the CSV file path
    std::string csv_file = output_dir + "/" + output_file;

    // Open the file in append mode
    std::ofstream log_file;
    bool file_already_exists = file_exists(csv_file);
    log_file.open(csv_file, std::ios::app);
    if (!log_file.is_open()) {
        std::cerr << "Failed to open or create the log file: " << csv_file << std::endl;
        return;
    }

    // If the file did not exist before, add column headers
    if (!file_already_exists) {
        log_file << "Timestamp,Top_Tier_Memory,Total_Memory,Memory_Limit\n";
    }

    // Write data to the CSV file
    log_file << current_time << "," << top_tier_memory << "," << total_memory << "," << memory_limit << "\n";

    log_file.close();
    std::cout << "Memory data logged successfully to " << csv_file << std::endl;
}

int main(int argc, char *argv[]) {
    if (argc < 5 || argc > 7) {
        std::cerr << "Usage: " << argv[0] << " -cg_idx <index> -output_dir <directory> [-output_file <filename>]" << std::endl;
        return 1;
    }

    int cg_idx = -1;
    std::string output_dir;
    std::string output_file = "memory_usage_log.csv";  // Default filename

    // Parse arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-cg_idx" && i + 1 < argc) {
            cg_idx = std::stoi(argv[++i]);
        } else if (arg == "-output_dir" && i + 1 < argc) {
            output_dir = argv[++i];
        } else if (arg == "-output_file" && i + 1 < argc) {
            output_file = argv[++i];
        } else {
            std::cerr << "Invalid argument: " << arg << std::endl;
            return 1;
        }
    }

    // Validate cg_idx and output_dir
    if (cg_idx == -1 || output_dir.empty()) {
        std::cerr << "Missing required arguments." << std::endl;
        return 1;
    }

    while (true) {
        // Log memory data with optional filename
        log_memory_data(cg_idx, output_dir, output_file);
        sleep(3);  // Sleep for 3 seconds between logs
    }

    return 0;
}

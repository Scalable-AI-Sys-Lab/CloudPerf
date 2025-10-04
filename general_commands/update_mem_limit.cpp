#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib>
#include <cctype>

// Function to print the usage of the program
void print_usage(const std::string &program_name) {
    std::cerr << "Usage: " << program_name << " -cg_idx <index> [-mem_limit_str <limit> | -mem_limit_value <limit>]" << std::endl;
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

int main(int argc, char *argv[]) {
    if (argc < 5) {
        print_usage(argv[0]);
        return 1;
    }

    int cg_idx = -1;
    std::string limit_str;
    uint64_t limit_value = 0;
    bool use_string_limit = false;

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
        } else {
            print_usage(argv[0]);
            return 1;
        }
    }

    // Check if cg_idx is valid
    if (cg_idx == -1) {
        print_usage(argv[0]);
        return 1;
    }

    // Check if we are using a string limit or a numeric limit
    if (use_string_limit) {
        // Call the function to update the memory limit with a string
        update_memory_limit_string(limit_str, cg_idx);
        std::cout << "Memory limit updated successfully for cgroup " << cg_idx << " with limit " << limit_str << std::endl;
    } else if (limit_value >= 0) {
        // Call the function to update the memory limit with a numeric value
        update_memory_limit_value(limit_value, cg_idx);
        std::cout << "Memory limit updated successfully for cgroup " << cg_idx << " with limit " << limit_value << " bytes" << std::endl;
    } else {
        print_usage(argv[0]);
        return 1;
    }

    return 0;
}

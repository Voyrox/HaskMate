#include "generate.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>

namespace generate
{

    void generateConfig()
    {
        const char *configTemplate =
            "{\n"
            "  \"delay\": 1000000,\n"
            "  \"ignore\": [],\n"
            "  \"cmd\": \"stack ghc -- {file} && {dir}/test\"\n"
            "}\n";

        std::ofstream file("Zippy.json", std::ios::out | std::ios::trunc | std::ios::binary);
        if (!file.is_open())
        {
            throw std::runtime_error("failed to write Zippy.json");
        }
        file << configTemplate;
        file.close();
        std::cout << "Configuration file generated successfully!\n";
    }

}

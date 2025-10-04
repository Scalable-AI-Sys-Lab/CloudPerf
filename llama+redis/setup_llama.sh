#!/bin/bash

# Clone the repository
git clone https://github.com/ggerganov/llama.cpp.git

# Change directory to the cloned repository
cd llama.cpp

# Install the required package
pip3 install -U "huggingface_hub[cli]"

# Create models directory if it doesn't exist and change to it
mkdir -p models
cd models

# Download the model using huggingface-cli
huggingface-cli download TheBloke/Llama-2-70B-GGUF llama-2-70b.Q4_K_M.gguf --local-dir . --local-dir-use-symlinks False

# Change directory back to llama.cpp
cd ..

# Build the project
make


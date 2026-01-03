#!/usr/bin/env bash

# This script downloads Whisper VAD model files that have already been converted
# to ggml format. This way you don't have to convert them yourself.

src="https://huggingface.co/ggml-org/whisper-vad"
pfx="resolve/main/ggml"

# Whisper VAD models
models="silero-v5.1.2 silero-v6.2.0"

# list available models
list_models() {
    printf "\n"
    printf "Available models:"
    model_class=""
    for model in $models; do
        this_model_class="${model%%[.-]*}"
        if [ "$this_model_class" != "$model_class" ]; then
            printf "\n "
            model_class=$this_model_class
        fi
        printf " %s" "$model"
    done
    printf "\n\n"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf "Usage: %s <model>\n" "$0"
    list_models
    exit 1
fi

model=$1

if ! echo "$models" | grep -q -w "$model"; then
    printf "Invalid model: %s\n" "$model"
    list_models

    exit 1
fi

# download ggml model

filename=ggml-"$model".bin
url="$src"/$pfx-"$model".bin

printf "Downloading ggml model %s from '%s' ...\n" "$model" "$src"

if [ -f "$filename" ]; then
    printf "Model %s already exists. Skipping download.\n" "$model"
    exit 0
fi

aria2c --no-conf -o ggml-"$model".bin "$url" && \
    printf "Done! Model '%s' saved to '%s'\n" "$model" "$filename"

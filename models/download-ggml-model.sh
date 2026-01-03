#!/usr/bin/env bash

set -e

# This script downloads Whisper model files that have already been converted to ggml format.
# This way you don't have to convert them yourself.

#src="https://ggml.ggerganov.com"
#pfx="ggml-model-whisper"

src="https://huggingface.co/ggerganov/whisper.cpp"
pfx="resolve/main/ggml"

BOLD="\033[1m"
RESET='\033[0m'

# Whisper models
models="tiny
tiny.en
tiny-q5_1
tiny.en-q5_1
tiny-q8_0
base
base.en
base-q5_1
base.en-q5_1
base-q8_0
small
small.en
small.en-tdrz
small-q5_1
small.en-q5_1
small-q8_0
medium
medium.en
medium-q5_0
medium.en-q5_0
medium-q8_0
large-v1
large-v2
large-v2-q5_0
large-v2-q8_0
large-v3
large-v3-q5_0
large-v3-turbo
large-v3-turbo-q5_0
large-v3-turbo-q8_0"

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

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    printf "Usage: %s <model> [--resume|-r]\n" "$0"
    list_models
    printf "___________________________________________________________\n"
    echo -e "${BOLD}.en${RESET} = english-only ${BOLD}-q5_[01]${RESET} = quantized ${BOLD}-tdrz${RESET} = tinydiarize\n"

    exit 1
fi

model=$1

if ! echo "$models" | grep -q -w "$model"; then
    printf "Invalid model: %s\n" "$model"
    list_models

    exit 1
fi

# check if model contains `tdrz` and update the src and pfx accordingly
if echo "$model" | grep -q "tdrz"; then
    src="https://huggingface.co/akashmjn/tinydiarize-whisper.cpp"
    pfx="resolve/main/ggml"
fi

# download ggml model

filename=ggml-"$model".bin
url="$src"/$pfx-"$model".bin

resume=()
msg_pfx=
if [[ "$2" =~ ^-([cr]|-(continue|resume))$ ]]; then
    resume=( -c )
    msg_pfx="Attempting to resume downloading"
else
    msg_pfx="Downloading"
fi

printf "%s ggml model %s from '%s' ...\n" "$msg_pfx" "$model" "$src"


if [[ -f "$filename" ]] && [[ ! ${#resume[@]} ]]; then
    printf "Model %s already exists. Skipping download.\n" "$model"
    exit 0
fi

aria2c --no-conf "${resume[@]}" -o ggml-"$model".bin "$url" && \
    printf "Done! Model '%s' saved to '%s'\n" "$model" "$filename"

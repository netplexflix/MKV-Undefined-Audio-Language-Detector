FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

LABEL maintainer="netplexflix"
LABEL description="ULDAS - Unified Language Detection and Subtitle Processing (NVIDIA GPU)"
LABEL org.opencontainers.image.source="https://github.com/netplexflix/ULDAS"

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3-pip \
    build-essential \
    curl \
    ca-certificates \
    xz-utils \
    mkvtoolnix \
    tesseract-ocr \
    tesseract-ocr-eng \
    gosu \
    tzdata \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libavfilter-dev \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Install a patched static FFmpeg (>= 8.1.2) to fix CVE-2026-8461
ARG FFMPEG_URL=https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz
RUN curl -fsSL -o /tmp/ffmpeg.tar.xz "$FFMPEG_URL" \
    && mkdir -p /tmp/ffmpeg \
    && tar -xJf /tmp/ffmpeg.tar.xz -C /tmp/ffmpeg --strip-components=1 \
    && install -m 0755 /tmp/ffmpeg/bin/ffmpeg /usr/local/bin/ffmpeg \
    && install -m 0755 /tmp/ffmpeg/bin/ffprobe /usr/local/bin/ffprobe \
    && rm -rf /tmp/ffmpeg /tmp/ffmpeg.tar.xz \
    && /usr/local/bin/ffmpeg -version | head -n1

WORKDIR /app

# Upgrade pip
RUN python -m pip install --upgrade pip setuptools wheel

# Install PyTorch with CUDA support
RUN pip install torch --index-url https://download.pytorch.org/whl/cu124

# Install PyAV (required by faster-whisper)
RUN pip install av

# Install remaining Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application code
COPY ULDAS.py .
COPY uldas ./uldas
RUN find /app/uldas -type f

# Create directories and copy config
RUN mkdir -p /app/config /media
COPY config/config.example.yml /app/config.example.yml
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV PUID=0
ENV PGID=0

EXPOSE 2119

ENTRYPOINT ["/entrypoint.sh"]
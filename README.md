# PHZ Full Stack debian32

## 1. Project Description

Build docker images for PHZ Debian i386 and amd64, published as the multi-arch image `phzfi/debian` on Docker Hub. https://hub.docker.com/r/phzfi/debian

Run `docker/build.sh` to build the docker images `phzfi/debian:bookworm-latest-i386` and `phzfi/debian:bookworm-latest-amd64`, combined into the multi-arch images `phzfi/debian:bookworm-<version>` and `phzfi/debian:bookworm-latest`.

See also:
 - https://github.com/ioft/dockerhub
 - http://mwhiteley.com/linux-containers/2013/08/31/docker-on-i386.html
 - https://dzone.com/articles/docker-daemon-for-32-bit-architecture

### 1.1. Business Vision

Use older 32bit hardware for sustainable development and sustainable code. Reduce waste.

### 1.2. Task Management

### 1.3. Personas

### 1.4. Use Cases

### 1.5. Non-Functional Requirements

## 2. Architecture

### 2.1. Technologies

* Docker 32bit and 64bit (multi-arch manifest list on Docker Hub)
* Debian (bookworm)
* debootstrap cross-build (the i386 chroot is executed by the host kernel's 32-bit support, qemu-user-static as fallback)
* Docker BuildKit (`docker build --platform`) to import the rootfs tar with correct architecture metadata
* Jenkins declarative multibranch pipeline
* Vagrant during building
* sh2ju for testing

### 2.2. Naming, Terms and Key Concepts

### 2.3. Coding Convention

## 3. Development Environment

### 3.1. Prerequisites

### 3.2. Start the Application

### 3.3. Access the Application

### 3.4. Run Tests

### 3.5. IDE Setup and Debugging

### 3.6. Version Control

### 3.7. Databases and Migrations

### 3.8. Continuous Integration

## 4. Staging Environment

### 4.1. Access

### 4.2. Deployment

### 4.3. Smoke Tests

#### 4.3.1. Automated Test Cases

#### 4.3.2. Manual Test Cases

### 4.4. Rollback

### 4.5. Logs

### 4.6. Monitoring

## 5. Production Environment

### 5.1. Access

### 5.2. Deployment

### 5.3. Smoke Tests

#### 5.3.1. Automated Test Cases

#### 5.3.2. Manual Test Cases

### 5.4. Rollback

### 5.5. Logs

### 5.6. Monitoring

## 6. Operating Manual

### 6.1 Scheduled Jobs

### 6.2 Manual Processes

## 7. Problems


#!/bin/bash
set -e -x

# CLI arguments
PY_VERSIONS=$1
BUILD_REQUIREMENTS=$2
SYSTEM_PACKAGES=$3
PRE_BUILD_COMMAND=$4
PACKAGE_PATH=$5
PIP_WHEEL_ARGS=$6
SOURCE=$7

# Temporary workaround for LD_LIBRARY_PATH issue. See
# https://github.com/RalfG/python-wheels-manylinux-build/issues/26
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib

cd "${GITHUB_WORKSPACE}"/"${PACKAGE_PATH}"

# Install findutils by default on images with APK (Alpine: musllinux). Required for `find -iregex`.
if command -v apk >/dev/null; then
    apk add findutils || { echo "Installing findutils with apk failed."; exit 1; }
fi

if [ ! -z "$SYSTEM_PACKAGES" ]; then
    if command -v apt-get >/dev/null; then
        apt-get update
        apt-get install -y ${SYSTEM_PACKAGES} || { echo "Installing apt package(s) failed."; exit 1; }
    elif command -v yum >/dev/null; then
        yum install -y ${SYSTEM_PACKAGES} || { echo "Installing yum package(s) failed."; exit 1; }
    elif command -v apk >/dev/null; then
        apk add ${SYSTEM_PACKAGES} || { echo "Installing apk package(s) failed."; exit 1; }
    else
        echo "Package managers apt, yum, or apk not found."; exit 1;
    fi
fi

if [ ! -z "$PRE_BUILD_COMMAND" ]; then
    eval $PRE_BUILD_COMMAND || { echo "Pre-build command failed."; exit 1; }
fi

# Compile wheels
arrPY_VERSIONS=(${PY_VERSIONS// / })
for PY_VER in "${arrPY_VERSIONS[@]}"; do
    # Update pip
    /opt/python/"${PY_VER}"/bin/pip install --upgrade --no-cache-dir pip

    # Check if requirements were passed
    if [ ! -z "$BUILD_REQUIREMENTS" ]; then
        /opt/python/"${PY_VER}"/bin/pip install --no-cache-dir ${BUILD_REQUIREMENTS} || { echo "Installing requirements failed."; exit 1; }
    fi

    # Build wheels
    /opt/python/"${PY_VER}"/bin/pip wheel ${SOURCE} ${PIP_WHEEL_ARGS} || { echo "Building wheels failed."; exit 1; }
done

# Bundle external shared libraries into the wheels
# find -exec does not preserve failed exit codes, so use an output file for failures
failed_wheels=$PWD/failed-wheels
rm -f "$failed_wheels"
find . -type f -iregex ".*-[manylinux|linux].*\.whl" -exec bash -c "auditwheel repair '{}' -w \$(dirname '{}') --plat '${PLAT}' || { echo 'Repairing wheels failed.'; auditwheel show '{}' &>> "$failed_wheels"; }" \;

if [[ -f "$failed_wheels" ]]; then
    sed -i '/This does not look like a platform wheel/d' "$failed_wheels"
fi

if [[ -s "$failed_wheels" ]]; then
    echo "Repairing wheels failed:"
    cat failed-wheels
    exit 1
fi

echo "Succesfully build wheels:"
find . -type f -iname "*-manylinux*.whl"

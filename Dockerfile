FROM ubuntu:18.04

ENV OPENCV_VERSION=3.4.1 \
BAZEL_VERSION=0.13.0 \
TENSORFLOW_VERSION=v1.8.0-rc1 \
PATH="${PATH}:/root/bin" \
DEBIAN_FRONTEND=noninteractive \
DEBCONF_NONINTERACTIVE_SEEN=true \
TF_NEED_CUDA=0 \
GCC_HOST_COMPILER_PATH=/usr/bin/gcc \
PYTHON_BIN_PATH="/usr/bin/python3" \
USE_DEFAULT_PYTHON_LIB_PATH=1 \
TF_NEED_JEMALLOC=1 \
TF_NEED_GCP=0 \
TF_NEED_HDFS=0 \
TF_ENABLE_XLA=0 \
TF_NEED_S3=0 \
TF_NEED_KAFKA=0 \
TF_NEED_GDR=0 \
TF_NEED_VERBS=0 \
TF_NEED_OPENCL=0 \
TF_NEED_MPI=0 \
TF_DOWNLOAD_CLANG=1 \
TF_SET_ANDROID_WORKSPACE=0

#General Setup
RUN apt-get update && \
apt-get install -y python3-dev python3-pip cifs-utils apt-utils apt-transport-https software-properties-common \
wget unzip curl nano git bzip2 ca-certificates grep sed dpkg libicu60 tzdata tesseract-ocr python-numpy python-scipy python-matplotlib vim && \
update-ca-certificates && \
echo "tzdata tzdata/Areas select America" > /tmp/preseed.txt \
echo "tzdata tzdata/Zones/America select Chicago" >> /tmp/preseed.txt && \
debconf-set-selections /tmp/preseed.txt

#Install opencv dependencies
RUN apt-get install -y build-essential cmake \
libgtkglext1-dev libvtk6-dev \
zlib1g-dev libjpeg-dev libwebp-dev libpng-dev libtiff5-dev libopenexr-dev libgdal-dev libatlas-base-dev gfortran && \
add-apt-repository "deb http://security.ubuntu.com/ubuntu xenial-security main" && apt update && apt install libjasper1 libjasper-dev && \
apt-get install -y libdc1394-22-dev libavcodec-dev libavformat-dev libswscale-dev libtheora-dev libvorbis-dev libxvidcore-dev \
libx264-dev yasm libopencore-amrnb-dev libopencore-amrwb-dev libv4l-dev libxine2-dev libtbb-dev libeigen3-dev

RUN pip3 install pillow pytesseract imutils numpy

WORKDIR /
#Install OpenCV
RUN wget https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
unzip ${OPENCV_VERSION}.zip && \
rm ${OPENCV_VERSION}.zip && \
mv opencv-${OPENCV_VERSION} OpenCVBuild && \
wget https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip && \
unzip ${OPENCV_VERSION}.zip && \
rm ${OPENCV_VERSION}.zip && \
mv opencv_contrib-${OPENCV_VERSION} OpenCV_contrib && \
cd OpenCVBuild && mkdir build && mkdir /OpenCV && cd build && \
cmake \
-D CMAKE_INSTALL_PREFIX=/OpenCV \
-D OPENCV_EXTRA_MODULES_PATH=/OpenCV_contrib/modules \
-D CMAKE_BUILD_TYPE=RELEASE \
-D BUILD_EXAMPLES=ON \
-D INSTALL_PYTHON_EXAMPLES=ON \
-D BUILD_DOCS=OFF \
-D BUILD_PERF_TESTS=OFF \
-D BUILD_TESTS=OFF \
-D BUILD_opencv_java=OFF \
-D BUILD_opencv_python3=ON \
-D BUILD_opencv_python2=OFF \
-D CPU_DISPATCH=SSE4_2,AVX,AVX2 \
-D BUILD_opencv_apps=OFF \
.. && \
make -j4 && \
make install && \
echo "/OpenCV/lib" >> /etc/ld.so.conf.d/opencv.conf && \
ldconfig -v && \
rm -rf /OpenCVBuild && \
rm -rf OpenCV_contrib

RUN export PKG_CONFIG_PATH=/OpenCV/lib/pkgconfig

WORKDIR /OpenCV/lib/python3.6/dist-packages
RUN mv cv2.cpython-36m-x86_64-linux-gnu.so cv2.so

WORKDIR /

#Install Tensorflow dependencies
RUN apt-get -y install python-pip python-wheel zip zlib1g-dev unzip patch && \
apt-get -y upgrade gcc g++ && \
wget https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
chmod +x bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
./bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh --user && \
rm bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
git clone https://github.com/tensorflow/tensorflow.git && \
cd /tensorflow && \
git fetch --all --tags --prune && \
git checkout ${TENSORFLOW_VERSION} && \
cd /tensorflow && \
./configure && bazel build -c opt --copt=-mavx --copt=-mavx2 --copt=-mfpmath=sse --copt=-msse4.2 --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=0 //tensorflow:libtensorflow.so --verbose_failures && \
mkdir /tflow && \
cp /tensorflow/bazel-bin/tensorflow/libtensorflow.so /tflow/libtensorflow.so && \
cp /tensorflow/bazel-bin/tensorflow/libtensorflow_framework.so /tflow/libtensorflow_framework.so

RUN cd /tensorflow && \
    bazel build -c opt --copt=-mavx --copt=-mavx2 --copt=-mfpmath=sse --copt=-msse4.2 --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=0 //tensorflow/tools/pip_package:build_pip_package

RUN cd /tensorflow &&  \
    ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt && \
    pip3 install /mnt/tensorflow-`echo $TENSORFLOW_VERSION | sed -e 's/[v\-]//g'`-cp36-cp36m-linux_x86_64.whl && \
    cd /tmp && \
    python3 -c "import tensorflow as tf; print(tf.__version__)"

RUN rm -fr ~/.bazel ~/.bazelrc && \
rm -rf ~/.cache && \
rm -rf /tensorflow


# Minimal kbuild file used only for DKMS builds.
#
# driver/Makefile pins KERNELDIR to `uname -r`, which is correct for building
# against the running kernel but wrong for DKMS: DKMS builds for kernels other
# than the running one and passes the right tree in ${kernel_source_dir}.
# Keeping a bare obj-m here lets kbuild use whatever tree DKMS hands it.
obj-m := ch343.o

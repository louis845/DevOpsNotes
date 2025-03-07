# GPU passthrough with libvirt
Note that this may not work with every kind of GPU and physical motherboard.

## Things to be aware
  1. Enable IOMMU (AMD-Vi / Intel VT-d) in physical motherboard settings
  2. Locate the PCIe bus of the GPU with `lspci -Dvvv`
  3. Use `pc-q35-4.2` (or newer) for the vCPU, don't use i440FX
     * i440FX doesn't emulate the PCIe bus same as modern motherboard chipsets
     * Cannot communicate with modern GPUs
     * Needs to configure virtual nvram for virtual BIOS settings memory
  4. Use host passthrough partial to emulate the CPU type equal to the host's CPU to make NVIDIA CUDA drivers work inside the VM
  5. Make sure no applications is using the GPU when doing GPU passthrough
     * Use server version of Ubuntu/Debian without graphical desktop environment
     * Or, disable NVIDIA and nouveau drivers for X11 [see here below](#disabling-nvidianouveau-drivers-for-x11)

## vCPU configuration example

```
<cpu mode='host-passthrough' check='partial'/>
  <os>
    <type arch='x86_64' machine='pc-q35-4.2'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
    <loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.fd</loader> <!-- Default configuration of NVRAM -->
    <nvram>/path/to/nvram.fd</nvram> <!-- NVRAM file tied to this VM. When this VM will be reused, don't modify/delete this file! -->
  </os>
  <features>
    <acpi/>
    <kvm>
      <hidden state='on'/>
    </kvm>
  </features>
```

## GPU configuration example
Note that an NVIDIA GPU usually has two functions, `0x0` usually for the graphics, and `0x1` for the audio. To passthrough multiple GPUs, one simply has to duplicate the hostdev XML tags below (and set the appropriate source and destination addresses).
```
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x1'/>
    </hostdev>
```

The source tag corresponds to the PCIe bus that the GPU is placed in the host physically, while the address outside the source corresponds to the virtual PCIe bus that the GPU will be attached to inside the VM. 

One can inspect which PCIe bus the GPU resides in using `lspci -Dvvv`. The format is `DDDD:BB:SS.F`, where `D` is the domain, `B` is the bus, `S` is slot and `F` is function. Note that the outputs are hexadecimal.

## Enabling IOMMU
The option IOMMU depends on the motherboard's setting in BIOS, which varies from motherboard to motherboard. Usually its under the "Advanced settings", or something like that. 

Afterwards, include `intel_iommu=on` inside the `GRUB_CMDLINE_LINUX` option of `/etc/default/grub` to enable IOMMU for the host.

## Disabling NVIDIA/nouveau drivers for X11
Navigate to `/usr/share/X11/xorg.conf.d`, and delete the contents of `10-nvidia.conf` (and other nvidia-related configurations). Also, add `nouveau.modeset=0` in `GRUB_CMDLINE_LINUX` option of `/etc/default/grub` to disable the nouveau drivers.

## Remote desktop sharing of host
Note that the remote desktop sharing program of Ubuntu makes uses of the NVIDIA GPU if available, even when GPUs are disabled. To enable the remote desktop sharing program, first turn off the RDP server by disabling it, start a VM that makes use of the GPU, and then turn on the RDP server.

## Complete libvirt XML configuration file example
```xml
<domain type='kvm'>
  <name>Example</name>
  <memory unit='GiB'>16</memory>
  <vcpu placement='static'>8</vcpu>
  <cpu mode='host-passthrough' check='partial'/>
  <os>
    <type arch='x86_64' machine='pc-q35-4.2'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
    <loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.fd</loader>
    <nvram>/path/to/vm_folder/nvram.fd</nvram>
  </os>
  <features>
    <acpi/>
    <kvm>
      <hidden state='on'/>
    </kvm>
  </features>
  <devices>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x1'/>
    </hostdev>

    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x07' slot='0x00' function='0x0'/>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x02' slot='0x00' function='0x1'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x07' slot='0x00' function='0x1'/>
    </hostdev>

    <disk type='file' device='disk'> <!-- Attach a virtual disk image file to the VM -->
      <driver name='qemu' type='qcow2'/>
      <source file='/path/to/vm_folder/image'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    
    <interface type='bridge'> <!-- Attach a specified virtual network bridge from the host to the VM -->
      <mac address='c6:f4:35:f8:98:c9'/>
      <source bridge='VMBridge'/>
      <model type='virtio'/>
    </interface>

    <video>
      <model type='vga' vram='2097152' heads='1'/> <!-- Allow graphics for the VM, and with virtual VRAM enough for high resolutions-->
    </video>

    <!-- Setting up SPICE to connect to within the VM -->
    <graphics type='spice' port='5902' listen='192.168.1.103'/>
    <console type='pty'/>
    <controller type='virtio-serial' index='0'/>
    <channel type='spicevmc'>
        <target type='virtio' name='com.redhat.spice.0'/>
    </channel>
  </devices>
</domain>
```

## QEMU commands for creating images
Here are some essential commands for manging VM images:
```
qemu-img create -f <image_type> <filename> <size>
qemu-img create -f qcow2 -F <backing image format> -b <path/to/backing/image> <filename> [new size]
qemu-img info <path/to/image>
qemu-img create -f raw -o preallocation=full <filename> <size>
```


# References
 * https://clayfreeman.github.io/gpu-passthrough/#imaging-the-gpu-rom
 * https://man7.org/linux/man-pages/man8/lspci.8.html
 * https://libvirt.org/formatdomain.html#host-device-assignment
 * https://qemu-project.gitlab.io/qemu/tools/qemu-img.html
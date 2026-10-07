# Running the Darkly v2 appliance

The appliance ships as a VirtualBox x86 OVA. On an Apple Silicon host we run it under
QEMU (full x86_64 emulation).

```bash
# 1. extract the disk from the OVA (do NOT commit it)
tar xf Darkly_v2.ova Darkly_v2-disk001.vmdk

# 2. convert to qcow2
qemu-img convert -O qcow2 Darkly_v2-disk001.vmdk darkly.qcow2

# 3. boot headless, forward guest :4942 -> host :4942
qemu-system-x86_64 -M pc -m 2048 -smp 2 -hda darkly.qcow2 \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:4942-:4942 \
  -device e1000,netdev=n0 -display none -daemonize

# 4. wait for boot, then:
curl http://localhost:4942/
```

On an Intel machine you can instead import the OVA into VirtualBox directly, as the
subject describes, and browse http://localhost:4942.

Note: emulation is CPU-only on Apple Silicon, so the VM boots slowly. To also reach the
internal PocketBase during testing, add `hostfwd=tcp:127.0.0.1:8090-:8090`.

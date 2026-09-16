# List of things that rai will not support

- SSH'ing as root to the vm. I want to keep everything root out of rai. Trust is central. I almost added a `--root` flag to `rai-ssh`, but that didn't feel right. If you want to root to your vm, you have to do that yourself.

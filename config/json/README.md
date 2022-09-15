Directory should contain config files containing GPU settings, with the naming 
convention:

```
<COIN>_<HASHRATE_TARGET>.json
```

For example, "eth_50.json", for an eth mining configuration targeting a 
hashrate of 50mh/s.  The list of acceptable coin names is currently limited by
a check at the top of the setupGPUs.sh file.

Most parameters are defined in a global defaults section, and can be overridden
in the GPU specific sections if necessary.  An example file is provided in this
directory.


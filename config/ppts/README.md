If you are using the PPT config method, this directory should contain the ppts 
for each of your GPUs.

The default config (as defined in the example file) looks for files with the 
naming convention:

```
${INSTANCE_ID}_${COIN}_${HR_TARGET}.bin.ppt
```

For example, "0_eth_55.bin.ppt", for the first card (by bus id order) configured to mine eth 
with a hashrate of 55mh/s.

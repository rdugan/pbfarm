# pbfarm

## Tools and configuration files for managing mining rigs using AMD GPUs.

The primary tool is the setupGPUs.sh script in the tools directory, which then 
expects to find all other required tools in the same directory.  This script
is called with a GPU ID (or a comma separated list of IDs, or 'all'), a coin 
name (e.g. 'eth'), and a hashrate target (e.g. '50').  For example:

```
setupGPUs.sh 0,1 eth 50
```
It will then consult a config file from the config/json directory with the name

```
<COIN>_<HASHRATE>.json
```
or following the previous example, 'eth_50.json'.  An example config file is
provided in the config/json directory.  The script will perform much of the GPU
configuration via PPT files - see the config/ppts/README for more information.

Best practice would be to run this script (as root) before starting the miner.


### Requirements

- Tools generally available via distro package managers
  - jq : for parsing the json config (Ubuntu package 'jq')
  - sponge : for writing ppts to GPU (Ubuntu package 'moreutils')
  - i2cset : for controlling memory voltage on VIIs (Ubuntu package 'i2c-tools')
- Other 3rd party tools
  - atitool : AMD in-house tool used for certain aspects of voltage control
  - amdmemtweak : for setting memory timings
  - upp : for reading ppt files to determine formatting of GPU status report


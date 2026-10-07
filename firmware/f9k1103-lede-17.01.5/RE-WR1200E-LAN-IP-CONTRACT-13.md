# RE — WR1200E R62 LAN IP contract 13

## Exact donor

Primary donor:

- Cudy WR1200E R62 / 2.4.25
- donor BIN SHA-256: `086055b0227910f9ddabbb13bfa6b06a3850105bd46a3572b76116bf5a3043fa`

Exact donor objects:

- `/bin/config_generate`
  - SHA-256: `623c0eb59f2a9a96a698735351ddf63f3d2692c2620846f562963443a6af4924`
- `/etc/uci-defaults/01_network`
  - SHA-256: `f66eb8824f2d955b5bd1fc74386598113d3fbfd233a21afe3ad7b292843bc0015`

## Proven behavior

The donor `config_generate` generic static LAN fallback is:

```sh
lan) ipad=${ipaddr:-"192.168.1.1"} ;;
```

However, stock Cudy `01_network` explicitly applies the Cudy management LAN contract:

```sh
uci -q get network.lan.def_ipaddr || {
    uci set network.lan.def_ipaddr="192.168.10.1"
    uci set network.lan.ipaddr='192.168.10.1'
}
```

This applies to WR1200E R62 through the default branch.

Therefore:

- `192.168.1.1` is the generic config_generate fallback;
- `192.168.10.1` is the later stock Cudy WR1200E firstboot LAN default;
- preserving donor `01_network` while copying a target `/etc/config/network` does **not** guarantee the final firstboot LAN remains `192.168.1.1`;
- if `network.lan.def_ipaddr` is absent, the Cudy default script changes the LAN to `192.168.10.1`.

Candidate-11/12 preserve donor `01_network` byte-identically, so tests which checked only `192.168.1.1` were insufficient to establish LAN reachability.

## F9K1103 engineering target override

For deterministic isolated physical testing, the F9K1103 adapter now changes only the runtime target LAN management address after stock donor defaults:

```sh
uci set network.lan.def_ipaddr='192.168.10.2'
uci set network.lan.ipaddr='192.168.10.2'
```

The donor `01_network` file itself remains unchanged.

Classification:

- donor 192.168.10.1 default: **DONOR_SOURCE_VERIFIED**
- previous 192.168.1.1-only test assumption: **CORRECTED**
- F9K1103 192.168.10.2 override: **TARGET_TEST_ADAPTER**
- physical no-carrier / no-Wi-Fi symptom: **NOT EXPLAINED BY IP ADDRESS**

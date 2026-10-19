# scfmDataPrep (development version)

- requires `scfmutils` >= 2.0.9.9007, whose `calibrateFireRegimePolys()` no longer fails when every flammable pixel of a fire regime polygon has 8 flammable neighbours (PredictiveEcology/scfm#22).

# scfmDataPrep 2.1.0

- Released with the scfm family at 2.1.0.

- changed `fireEpoch` from 1970-2020 in order to expand input data so that more wildfire is detected on the landscape
- new parameter `.clusterTypeFireRegimePolys` sets the cluster type for the parallel calibration. Forked workers, pemisc's default except on Windows, deadlocked when the module ran inside a multithreaded process such as a `crew` worker; use `"PSOCK"` there.

# scfmDataPrep 0.0.1 (04 February 2025)

- initial module version

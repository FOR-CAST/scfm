## PredictiveEcology/scfm#22: the scfmDriver step (scfmutils::calibrateFireRegimePolys()) finds p0
## with optimise() over [hatP0(pEscape, 8), hatP0(pEscape, floor(mean number of flammable
## neighbours))]. When every flammable cell of a fire regime polygon has 8 flammable neighbours,
## the two ends are equal.
##
## The toy landscape is all flammable, in 250 m (6.25 ha) pixels. The calibration area is
## 0-10 km square (40 x 40 pixels) and the study area the 2.5-7.5 km square inside it (20 x 20).
## Fire regime polygon 1 is the 3.75-6.25 km block in the middle of the study area (10 x 10 pixels),
## so all of its pixels have 8 flammable neighbours; polygon 2 is the rest of the calibration area.

withr::local_options(list(
  spades.moduleCodeChecks = FALSE,
  spades.useRequire = FALSE,
  reproducible.useCache = FALSE,
  reproducible.verbose = -2,
  scfmutils.driver.plot.scam = FALSE
))

toyBox <- function(lo, hi) {
  sf::st_as_sfc(sf::st_bbox(c(xmin = lo, ymin = lo, xmax = hi, ymax = hi), crs = sf::st_crs(3005)))
}

toyRas <- function(lo, hi) {
  terra::rast(
    xmin = lo,
    xmax = hi,
    ymin = lo,
    ymax = hi,
    resolution = 250,
    crs = "EPSG:3005",
    vals = 1L
  )
}

## 100 lightning fires per polygon over 1971-2020: 70 of 1 ha, and 30 larger than one pixel (escapes,
## so pEscape = 0.3) whose log sizes in pixels follow a truncated exponential, so that the
## Hannon-Dahiya maximum fire size estimate converges
toyFirePoints <- function(frpc) {
  escapes <- round(6.25 * exp(scfmutils::qTE(stats::ppoints(30), theta = 1, T = 3)), 1)
  sizes <- c(rep(1, 70), escapes)
  pts <- lapply(frpc$PolyID, function(id) {
    sf::st_sf(
      CAUSE = "N",
      YEAR = rep_len(1971:2020, length(sizes)),
      SIZE_HA = sizes,
      geometry = sf::st_sample(frpc[frpc$PolyID == id, ], size = length(sizes))
    )
  })
  do.call(rbind, pts)
}

## simInit() + spades() of scfmDataPrep's init event over the toy landscape
toySim <- function(eventsToPrepare = c("scfmLandcoverInit", "scfmRegime", "scfmDriver")) {
  withr::local_seed(123)
  block <- toyBox(3750, 6250)
  calib <- toyBox(0, 10000)
  frpc <- sf::st_sf(PolyID = 1:2, geometry = c(block, sf::st_difference(calib, block)))
  root <- withr::local_tempdir(.local_envir = parent.frame())
  sim <- suppressMessages(SpaDES.core::simInit(
    times = list(start = 1, end = 1),
    modules = "scfmDataPrep",
    params = list(
      scfmDataPrep = list(
        eventsToPrepare = eventsToPrepare,
        sliverThreshold = 1e5,
        targetN = 200,
        .plotInitialTime = NA,
        .useCache = FALSE,
        .useParallelFireRegimePolys = FALSE
      )
    ),
    objects = list(
      studyArea = sf::st_sf(geometry = toyBox(2500, 7500)),
      studyAreaCalibration = sf::st_sf(geometry = calib),
      fireRegimePolysCalibration = frpc,
      rasterToMatch = toyRas(2500, 7500),
      rasterToMatchCalibration = toyRas(0, 10000),
      flammableMap = toyRas(2500, 7500),
      flammableMapCalibration = toyRas(0, 10000),
      firePoints = toyFirePoints(frpc)
    ),
    paths = list(
      modulePath = normalizePath(testthat::test_path("..", "..", "..")),
      cachePath = root,
      inputPath = root,
      outputPath = root
    )
  ))
  suppressMessages(SpaDES.core::spades(sim, debug = FALSE))
}

## the fire regime attributes of polygon 1 (the central block), without geometry
block <- function(sim) {
  frp <- sf::st_drop_geometry(sim$fireRegimePolys)
  frp[frp$PolyID == 1, ]
}

test_that("the toy central polygon has only pixels with 8 flammable neighbours, and 0 < pEscape < 1", {
  frp1 <- block(toySim(c("scfmLandcoverInit", "scfmRegime")))
  expect_equal(frp1$nNbr_8, frp1$nFlammable)
  expect_gt(frp1$pEscape, 0)
  expect_lt(frp1$pEscape, 1)
})

test_that("scfmDriver calibrates p0 when every flammable pixel has 8 flammable neighbours (scfm#22)", {
  frp1 <- block(toySim())
  ## 1 - (1 - p0)^8 = pEscape, as every pixel of polygon 1 has 8 flammable neighbours
  expect_equal(1 - (1 - frp1$p0)^8, frp1$pEscape, tolerance = 0.01)
})

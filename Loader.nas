#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Loader for the Radar module.
#

io.load_nasal(resolvepath("FGUM/Radar/MOLG.nas"),                  "FGUM_Radar_MOLG");
io.load_nasal(resolvepath("FGUM/Radar/RadarContact.nas"),          "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/Radar.nas"),                 "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/RangeFilter.nas"),           "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/SignalFilter.nas"),          "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/TerrainLOSFilter.nas"),      "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/RectangularSolidAngle.nas"), "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/AMSAScanShapeFilter.nas"),   "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/DopplerFilter.nas"),         "FGUM_Radar");
io.load_nasal(resolvepath("FGUM/Radar/MemoryModule.nas"),          "FGUM_Radar");

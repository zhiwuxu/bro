
include(BroPlugin)

include_directories(BEFORE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

bro_plugin_begin(Bro ConfigReader)
bro_plugin_cc(Config.cc Plugin.cc)
bro_plugin_bif(config.bif)
bro_plugin_end()

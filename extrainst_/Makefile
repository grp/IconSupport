TOOL_NAME = extrainst_
extrainst__INSTALL_PATH = /DEBIAN

extrainst__OBJC_FILES = main.mm
extrainst__FRAMEWORKS = UIKit
extrainst__OBJCCFLAGS = -DAPP_ID=\"$(APP_ID)\" -I ../Common -include Firmware.h -fvisibility=hidden

include ../theos/makefiles/common.mk
include ../theos/makefiles/tool.mk

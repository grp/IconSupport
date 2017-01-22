TWEAK_NAME = IconSupport

IconSupport_OBJCC_FILES = IconSupport.xm IconSupportClassic.xm ISIconSupport.mm ISAlertItem.xm ISLayoutRepairedAlertItem.xm ISStaleFileAlertItem.xm Preferences.xm
IconSupport_FRAMEWORKS = UIKit CoreGraphics
IconSupport_OBJCCFLAGS = -DAPP_ID=\"$(APP_ID)\" -I ../Common -include Headers.h -include Firmware.h -fvisibility=hidden

ARCHS ?= armv6 arm64
GO_EASY_ON_ME = 1

include ../theos/makefiles/common.mk
include ../theos/makefiles/tweak.mk

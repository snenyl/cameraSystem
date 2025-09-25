# Makefile
PACKAGE_NAME = FS25_CameraSystem.zip

build:
	mkdir -p dist
	cp -r data src icon_cameraSystem.dds modDesc.xml dist/
	cd dist && zip -r ../$(PACKAGE_NAME) ./*
	rm -rf dist

clean:
	rm -f $(PACKAGE_NAME)

.PHONY: build test format declare

build:
	scarb build

format:
	scarb fmt

test:
	scarb test

declare:
	starkli declare target/dev/pufu_${CONTRACT}.sierra.json 

declare-pufu:
	$(MAKE) declare CONTRACT=pufu

declare-erc20:
	$(MAKE) declare CONTRACT=erc20

declare-erc721:
	$(MAKE) declare CONTRACT=erc721

setup-components:
	starkli invoke 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:main:skeleton str:main:skeleton str:MAIN:SKELETON / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:background:red str:background:red str:BG:RED / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:background:purple str:background:purple str:BG:PURPLE / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:background:green str:background:green str:BG:GREEN / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:body:yellow str:body:yellow str:BODY:YELLOW / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:body:green str:body:green str:BODY:GREEN / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:body:blue str:body:blue str:BODY:BLUE / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:body:red str:body:red str:BODY:RED / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:foot:spider str:foot:spider str:FOOT:SPIDER / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:foot:baloon str:foot:baloon str:FOOT:BALOON / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:foot:ski str:foot:ski str:FOOT:SKI / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_component str:foot:walker str:foot:walker str:FOOT:WALKER --watch

setup-sources:
	starkli invoke 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_source 0x0783a9097b26eae0586373b2ce0ed3529ddc44069d1e0fbc4f66d42b69d6850d 2 str:main:skeleton str:background:purple --watch
	
setup-tokens:
	starkli invoke 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_token 0x0783a9097b26eae0586373b2ce0ed3529ddc44069d1e0fbc4f66d42b69d6850d u256:946306795967 2 str:body:yellow str:foot:spider / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_token 0x0783a9097b26eae0586373b2ce0ed3529ddc44069d1e0fbc4f66d42b69d6850d u256:489957296332 2 str:body:green str:foot:baloon / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_token 0x0783a9097b26eae0586373b2ce0ed3529ddc44069d1e0fbc4f66d42b69d6850d u256:333346360165 2 str:body:red str:foot:baloon / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_token 0x0783a9097b26eae0586373b2ce0ed3529ddc44069d1e0fbc4f66d42b69d6850d u256:846998110073 2 str:body:blue str:foot:ski / 0x0070428f73215f95855b5df872ea731e692766a862588a94701d2f546342a882 register_token 0x0783a9097b26eae0586373b2ce0ed3529ddc44069d1e0fbc4f66d42b69d6850d u256:568512409807 2 str:body:blue str:foot:walker --watch
	
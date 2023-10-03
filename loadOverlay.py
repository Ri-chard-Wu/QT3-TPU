from pynq import Overlay
ol = Overlay('overlay/tinyTPU.bit')


IP_BASE_ADDRESS = ol.ip_dict['tinyTPU_0']['phys_addr']
ADDRESS_RANGE = ol.ip_dict['tinyTPU_0']['addr_range']

print(f"ADDRESS_RANGE: {ADDRESS_RANGE}")
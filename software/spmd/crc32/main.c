#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

unsigned int table[256] __attribute__ ((section (".dram"))) = {
0,          0x77073096, 0xEE0E612C, 0x990951BA,
0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE,
0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC,
0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940,
0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116,
0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A,
0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818,
0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C,
0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2,
0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086,
0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4,
0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8,
0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE,
0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252,
0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60,
0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04,
0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A,
0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E,
0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C,
0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0,
0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6,
0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D
};

unsigned char data[2048] __attribute__ ((section (".dram"))) = {
0x95, 0xD7, 0xE1, 0x6C, 0x7C, 0x89, 0xD9, 0x7E, 0x48, 0xB0, 0xA7, 0xB8, 0xF6, 0x2A, 0xD8, 0x3F,
0xD9, 0x12, 0x36, 0x8B, 0xA5, 0x35, 0xB3, 0xFF, 0x6F, 0xC5, 0x52, 0x73, 0xDA, 0xDD, 0xFA, 0x92,
0x1E, 0xA9, 0xED, 0xD1, 0x46, 0x7E, 0xEA, 0x47, 0xEC, 0x80, 0xCF, 0x6B, 0xC1, 0x72, 0xE3, 0x95,
0x97, 0x07, 0xE5, 0xA7, 0xAC, 0xDA, 0x1D, 0x71, 0x97, 0x8B, 0x22, 0x09, 0xBB, 0xF6, 0xAE, 0x02,
0xF5, 0xC5, 0xC2, 0x40, 0x0E, 0x95, 0x46, 0x40, 0x44, 0x30, 0x7E, 0xA1, 0x1B, 0xD6, 0xDD, 0xAE,
0x77, 0xC3, 0x5A, 0xA2, 0xCE, 0x09, 0x5D, 0x8D, 0x11, 0x74, 0x5E, 0xA4, 0xDB, 0xC7, 0x24, 0x87,
0x72, 0x3B, 0xC4, 0x19, 0x53, 0x5C, 0x2B, 0xD6, 0xF2, 0xC8, 0x98, 0x74, 0xA2, 0x99, 0x7D, 0xE6,
0xE2, 0xB0, 0xE7, 0x03, 0x52, 0xDF, 0x93, 0x84, 0xF4, 0x81, 0x11, 0x96, 0x73, 0x24, 0x22, 0xD5,
0x7E, 0xD0, 0xD7, 0xDA, 0xB3, 0xE5, 0x47, 0x63, 0x13, 0x18, 0x22, 0x76, 0xAB, 0xC6, 0x2F, 0xB3,
0xE6, 0xBA, 0xE8, 0xF6, 0x4A, 0x3B, 0x4B, 0x4B, 0xC3, 0x25, 0xF9, 0xE0, 0x4A, 0x72, 0x5B, 0xCE,
0x5A, 0x3D, 0xD1, 0x60, 0xD7, 0xE4, 0x7B, 0x5A, 0xEF, 0xAB, 0xBA, 0xE9, 0xFB, 0xE5, 0xF8, 0xB7,
0xD2, 0xD6, 0x45, 0x14, 0x0F, 0xB6, 0x86, 0x5F, 0x62, 0xA3, 0xF3, 0xC3, 0xA9, 0x3F, 0xFE, 0xB2,
0x4F, 0x95, 0xDD, 0x27, 0xB0, 0xA6, 0xFA, 0xC2, 0xD3, 0x27, 0xA5, 0x32, 0xA8, 0x28, 0x53, 0x83,
0xBA, 0xCA, 0x35, 0x58, 0xB6, 0x92, 0xC3, 0x34, 0x46, 0xDB, 0x77, 0x92, 0x58, 0xE6, 0xFA, 0xC1,
0x78, 0xFD, 0xAE, 0x4F, 0xC0, 0xD5, 0xCA, 0x93, 0xD7, 0x90, 0x4C, 0x33, 0x3E, 0x46, 0xF2, 0xB4,
0x78, 0x6E, 0x91, 0x33, 0xB9, 0xC8, 0x79, 0xE4, 0xAA, 0xA5, 0x97, 0xAE, 0x87, 0x2F, 0x79, 0xE5,
0xC1, 0x66, 0xDC, 0x8B, 0x1C, 0xF1, 0x9A, 0xFC, 0x30, 0x6D, 0x62, 0xE7, 0xB5, 0xE5, 0x51, 0x4B,
0xF7, 0xB1, 0xD9, 0x79, 0xB2, 0x8A, 0x8C, 0x18, 0x49, 0xC7, 0xB7, 0xA1, 0x11, 0xBE, 0xA4, 0x1E,
0xCC, 0x3B, 0xA6, 0x02, 0x21, 0xA1, 0x5D, 0xFE, 0xC4, 0xCD, 0x15, 0x0F, 0x0B, 0xF0, 0x43, 0x3F,
0xD1, 0xD2, 0x48, 0xF5, 0x2D, 0x14, 0x18, 0x30, 0x75, 0x51, 0x2E, 0x02, 0x42, 0xAE, 0xB1, 0xDF,
0x33, 0xB7, 0x5A, 0x54, 0xFA, 0xF9, 0x18, 0xDE, 0x68, 0x04, 0x93, 0x49, 0x7B, 0x3C, 0x0A, 0xD9,
0x91, 0xAB, 0xC6, 0xFF, 0x7A, 0xA5, 0xD0, 0x9C, 0xBB, 0xA0, 0x79, 0xBD, 0xD8, 0x75, 0xA9, 0x72,
0x75, 0x1F, 0x75, 0x9C, 0x94, 0xC6, 0xF3, 0xDD, 0x16, 0x52, 0xCA, 0x5F, 0x0E, 0x12, 0x94, 0x99,
0x3C, 0x5D, 0x3D, 0x01, 0x72, 0xF3, 0x4A, 0x78, 0xC8, 0xEF, 0xAA, 0x7D, 0xB9, 0x4F, 0x53, 0x0C,
0x46, 0xFE, 0x16, 0xEA, 0xED, 0x41, 0x3D, 0x5D, 0x04, 0x9A, 0x6B, 0x63, 0x17, 0x3E, 0x42, 0xD1,
0x2F, 0xED, 0xA8, 0x4A, 0xC2, 0x41, 0xE6, 0x23, 0xAA, 0x0E, 0x24, 0x45, 0x1F, 0x0A, 0x08, 0x5C,
0x19, 0x3E, 0x6E, 0x93, 0x81, 0xDB, 0xC3, 0x05, 0xD7, 0x06, 0xD3, 0x03, 0x14, 0xE2, 0xB0, 0x19,
0xE2, 0x3F, 0xD2, 0x12, 0xB3, 0x1E, 0x13, 0xF2, 0xB5, 0xD2, 0x90, 0xBD, 0x4C, 0x6D, 0x61, 0x57,
0xC5, 0x8D, 0x21, 0xB7, 0x01, 0xC0, 0xF1, 0xC0, 0x86, 0x1F, 0x8A, 0xFA, 0xE8, 0x55, 0x2A, 0xD5,
0xBB, 0xD9, 0xE4, 0x2A, 0x92, 0x6D, 0x7A, 0x44, 0x33, 0x89, 0xF1, 0x2C, 0xE0, 0xA2, 0x76, 0x6F,
0x72, 0x10, 0x02, 0xA4, 0xF0, 0x7F, 0x6B, 0x53, 0x2E, 0xA2, 0x03, 0x10, 0x57, 0x87, 0x12, 0x49,
0xCD, 0xEF, 0x64, 0x73, 0xE9, 0x2E, 0x0B, 0x59, 0x7D, 0x34, 0x1A, 0x4A, 0xB1, 0xAA, 0x39, 0x08,
0xA5, 0xA0, 0x72, 0xE8, 0x5E, 0xBB, 0xCA, 0x38, 0x78, 0xA4, 0x1E, 0xE8, 0xE9, 0xFF, 0x01, 0xE6,
0x41, 0xB5, 0xD9, 0x7B, 0x69, 0xFD, 0x33, 0x98, 0x10, 0xBE, 0xE6, 0xD7, 0x36, 0xB2, 0xF8, 0x83,
0xB9, 0xD5, 0x33, 0xE3, 0x54, 0x8E, 0x69, 0x76, 0x4C, 0xF0, 0x82, 0x3C, 0xA9, 0x2E, 0xC5, 0xF0,
0xDA, 0x3A, 0x17, 0xF5, 0x36, 0xA8, 0x43, 0xB4, 0x89, 0xFA, 0xC4, 0x4D, 0x11, 0x65, 0x73, 0x2F,
0x97, 0x0A, 0x45, 0xE1, 0x76, 0x67, 0x27, 0x8D, 0xD5, 0x42, 0xCC, 0x79, 0xB5, 0xA8, 0xFD, 0x3D,
0xCB, 0x64, 0x9C, 0x9D, 0xB6, 0xF8, 0x1A, 0x5A, 0x3B, 0x46, 0x39, 0x91, 0xD1, 0x55, 0x3C, 0x40,
0x2E, 0xC5, 0x69, 0xF3, 0x33, 0x96, 0x72, 0x60, 0x0B, 0xA9, 0xD7, 0xBA, 0x6B, 0xA9, 0xC3, 0x5A,
0x1F, 0xCB, 0x6A, 0x43, 0xFC, 0x0E, 0xF3, 0x16, 0x5B, 0xD4, 0x01, 0x30, 0x56, 0x48, 0xFB, 0x96,
0x98, 0x35, 0x67, 0x49, 0x63, 0x8E, 0x5B, 0x78, 0x39, 0x98, 0x8F, 0x6A, 0xC4, 0x75, 0x04, 0x70,
0x7A, 0x0E, 0xEC, 0x53, 0xD2, 0x73, 0x39, 0x32, 0x20, 0x85, 0x2F, 0x85, 0xB5, 0x05, 0xE5, 0x8C,
0xCB, 0x94, 0xEE, 0xFF, 0x33, 0xA1, 0x8E, 0x55, 0xD8, 0xBF, 0x92, 0xE1, 0x9E, 0x00, 0x9C, 0xD1,
0x0D, 0x00, 0xDA, 0x31, 0x68, 0x7E, 0xE7, 0x9E, 0xE8, 0x16, 0xE6, 0xA2, 0x56, 0xD1, 0x3A, 0x5F,
0x6B, 0x29, 0x57, 0xBD, 0x4B, 0xCA, 0xD1, 0x23, 0xFF, 0x12, 0x76, 0x4B, 0x64, 0x53, 0xFB, 0x12,
0x49, 0x8C, 0x2D, 0x65, 0x08, 0x14, 0x8F, 0x10, 0xB4, 0x8B, 0xAC, 0x7C, 0xAB, 0x37, 0x46, 0xEA,
0x66, 0x6E, 0x1C, 0x63, 0xD9, 0x00, 0xA3, 0x73, 0xA3, 0x1C, 0x6B, 0x9B, 0xC5, 0xD0, 0xE0, 0x20,
0x00, 0x61, 0x14, 0x7D, 0xD7, 0x39, 0x61, 0xCC, 0x6D, 0xA7, 0x12, 0x8E, 0xB0, 0x9A, 0x48, 0x10,
0xA1, 0xB1, 0x26, 0xC4, 0x4A, 0xBC, 0x7C, 0x31, 0x6E, 0x2D, 0x00, 0x0F, 0xBA, 0x9C, 0x2A, 0x62,
0x3E, 0xFE, 0xB1, 0x64, 0x76, 0x1B, 0xC4, 0xB8, 0x78, 0x20, 0x68, 0xDE, 0x7D, 0xEC, 0xA6, 0x0A,
0xA6, 0x8B, 0xF8, 0xF5, 0x78, 0xC9, 0xEB, 0xDC, 0x8B, 0x7C, 0x78, 0xDC, 0x93, 0x38, 0x1E, 0x06,
0x93, 0xF7, 0xD8, 0xAC, 0x92, 0x51, 0xD2, 0x7F, 0x8A, 0xAD, 0x59, 0x6D, 0xC3, 0xCF, 0x75, 0x15,
0xC7, 0xBE, 0x19, 0x73, 0x67, 0xA5, 0x05, 0x36, 0x30, 0x76, 0x27, 0x10, 0x0C, 0x3D, 0xDF, 0x09,
0x1A, 0x54, 0x2D, 0x96, 0x90, 0xB2, 0xB1, 0xDA, 0x08, 0xB8, 0x19, 0x97, 0xC7, 0x83, 0x4F, 0x47,
0x55, 0x85, 0xEC, 0x31, 0x8D, 0x3E, 0xE7, 0xA6, 0xC8, 0x83, 0x2C, 0xD6, 0xEC, 0xC5, 0x5C, 0x57,
0xED, 0x2C, 0x16, 0xC5, 0xD3, 0xA2, 0x8F, 0xD8, 0xCB, 0x8C, 0xCA, 0xC5, 0x92, 0xE7, 0xC4, 0x3D,
0x3D, 0x69, 0x28, 0x5E, 0xB3, 0xE4, 0xA7, 0xC1, 0xE3, 0x19, 0xA1, 0xA9, 0xA4, 0xCB, 0xC2, 0xB4,
0xD7, 0x10, 0x15, 0xA2, 0x2F, 0x8A, 0xDA, 0xE5, 0xB1, 0x42, 0x3C, 0x0A, 0xEC, 0x92, 0x74, 0x69,
0x09, 0x92, 0x0B, 0xC8, 0xF5, 0x80, 0x5A, 0xF6, 0x77, 0xFF, 0x51, 0x03, 0x6A, 0x47, 0xB2, 0x4C,
0x8C, 0x5F, 0x07, 0x36, 0xA1, 0x90, 0xF5, 0x3E, 0x0A, 0x71, 0x73, 0x0D, 0xCE, 0xC8, 0x89, 0x20,
0xAB, 0xDD, 0x21, 0xE2, 0x36, 0xED, 0xD8, 0xD0, 0x66, 0x31, 0xD6, 0x64, 0xBE, 0xB2, 0x6D, 0xF4,
0x1A, 0xA0, 0x1F, 0xAB, 0xB9, 0x48, 0x74, 0xB1, 0x40, 0xDB, 0x09, 0xB3, 0xF8, 0xFA, 0xB3, 0x7B,
0x3A, 0x77, 0x2A, 0xA7, 0x2B, 0x09, 0x86, 0x1C, 0xC6, 0x93, 0xED, 0x12, 0xA9, 0x28, 0x77, 0x60,
0x40, 0xE2, 0x9D, 0xC0, 0x31, 0xCA, 0x10, 0xE9, 0x9D, 0xA6, 0x1B, 0xBB, 0x4E, 0x5E, 0x91, 0x9F,
0xC8, 0xAB, 0x47, 0xA8, 0xEE, 0xA3, 0xE6, 0x74, 0x88, 0xF0, 0xFE, 0xE0, 0x93, 0xF3, 0x0A, 0x97,
0x5C, 0x12, 0x5F, 0xD6, 0xC6, 0x8D, 0x48, 0x3A, 0x72, 0x88, 0x8F, 0x30, 0x7F, 0xF7, 0xE4, 0x54,
0x12, 0xA6, 0xB0, 0x0B, 0xB3, 0x5C, 0xE1, 0x54, 0xEA, 0xE1, 0x96, 0x38, 0x48, 0x07, 0xD5, 0x39,
0x0C, 0x8B, 0xEF, 0x94, 0x01, 0x5C, 0xD3, 0x52, 0x1F, 0xF2, 0xFB, 0xC7, 0xF1, 0x5F, 0x5C, 0xB6,
0x9B, 0x68, 0x0B, 0x97, 0x31, 0x94, 0xCD, 0xF5, 0x14, 0x4E, 0x63, 0xEC, 0x45, 0x1A, 0xF5, 0x99,
0xF4, 0x23, 0x04, 0xE8, 0xCC, 0x07, 0x09, 0x54, 0x7C, 0x39, 0xC4, 0x46, 0x14, 0x4B, 0x0F, 0x9F,
0x1D, 0x2C, 0x49, 0x52, 0x60, 0xAD, 0xA8, 0xC8, 0x76, 0xB6, 0xA2, 0x45, 0xB0, 0xE9, 0x1E, 0x12,
0xD6, 0xA8, 0x7B, 0xE1, 0xD5, 0x51, 0xCA, 0xD6, 0x7A, 0x16, 0xA2, 0x5D, 0x2F, 0x01, 0x18, 0xF2,
0xFA, 0x6B, 0xC7, 0xA7, 0x61, 0x2B, 0x62, 0xBA, 0x92, 0xEE, 0x69, 0xE4, 0x08, 0x2C, 0x01, 0xCC,
0x50, 0xF1, 0x4B, 0xA3, 0x84, 0xE8, 0x0F, 0xBA, 0x1C, 0x1C, 0x91, 0x32, 0xC5, 0x8C, 0x36, 0x3B,
0x97, 0x6F, 0xED, 0x30, 0x5E, 0xF9, 0xA5, 0xE7, 0x34, 0x22, 0xA2, 0x6C, 0xF3, 0x15, 0xA2, 0x5C,
0x66, 0x0A, 0x7A, 0x9B, 0x7D, 0xFE, 0xDB, 0x46, 0xEF, 0x1B, 0x4D, 0xEB, 0x77, 0x85, 0xC5, 0x6C,
0x6C, 0x8F, 0x3C, 0x1D, 0xC6, 0xF1, 0x71, 0xF9, 0x3B, 0xB7, 0xA5, 0xE0, 0x9C, 0x3A, 0x3A, 0x93,
0x36, 0x1E, 0xC3, 0x2D, 0x62, 0x2E, 0x5B, 0x25, 0xA6, 0x2B, 0x36, 0x7C, 0x92, 0x40, 0x03, 0x70,
0x3B, 0x23, 0x18, 0x84, 0x01, 0x2F, 0x69, 0x7A, 0xCD, 0xBD, 0x63, 0xC3, 0x96, 0x61, 0x3C, 0xDE,
0x1C, 0x84, 0x71, 0x68, 0x9D, 0x84, 0xE5, 0x0A, 0xFF, 0x06, 0x5C, 0x14, 0xD1, 0x98, 0x22, 0xF1,
0xE2, 0x18, 0x90, 0x2A, 0xA0, 0x41, 0xFC, 0xAC, 0x7F, 0x1A, 0x54, 0xAF, 0x1A, 0x36, 0xE7, 0xEA,
0x1F, 0xD6, 0x3B, 0x59, 0xAD, 0x70, 0x85, 0x0C, 0x17, 0xE0, 0x52, 0xC0, 0xE1, 0xC8, 0x21, 0x96,
0xFC, 0x0B, 0xEF, 0x28, 0xAF, 0x46, 0xC0, 0x26, 0x6E, 0xD4, 0x9E, 0xC2, 0x24, 0xA9, 0x84, 0xA0,
0x0A, 0xCD, 0x31, 0x3B, 0xE6, 0x7B, 0x32, 0xDE, 0x10, 0xC6, 0xBB, 0x22, 0x3F, 0xCF, 0x72, 0x86,
0x37, 0x42, 0x9A, 0x0F, 0xC9, 0x3F, 0xEF, 0x18, 0x2F, 0xB3, 0x2F, 0x77, 0xEB, 0xB1, 0x76, 0x0B,
0xFA, 0x89, 0x84, 0x6A, 0x34, 0xB6, 0xEE, 0xB8, 0x42, 0x08, 0x1D, 0x62, 0x56, 0x8C, 0xD2, 0x85,
0x7D, 0x9D, 0x8E, 0x44, 0x9A, 0xCA, 0x6E, 0x4C, 0xC3, 0x4B, 0xBA, 0x86, 0x32, 0x73, 0x7F, 0xE4,
0xCE, 0xC4, 0x96, 0x71, 0x6A, 0x83, 0x71, 0xA3, 0xF7, 0xC9, 0x36, 0xF5, 0x49, 0x00, 0x44, 0x78,
0xC2, 0x53, 0xB4, 0x75, 0x1F, 0x67, 0x06, 0xD1, 0x89, 0x22, 0x26, 0x13, 0x5B, 0x0D, 0x64, 0x9D,
0x6F, 0xEA, 0x49, 0x24, 0x2F, 0x34, 0x09, 0xFF, 0xCA, 0x08, 0xAC, 0x4B, 0x7D, 0x23, 0xDB, 0x2E,
0xEF, 0x33, 0x98, 0x65, 0xD4, 0x19, 0x42, 0xE2, 0x2D, 0xDA, 0x7B, 0x4F, 0x13, 0x09, 0x10, 0x97,
0xD6, 0xE9, 0x18, 0x30, 0xEB, 0x3D, 0x57, 0x63, 0x0B, 0x31, 0x34, 0x54, 0xB1, 0x2A, 0x75, 0xA7,
0x31, 0x46, 0xDA, 0x52, 0xE5, 0xA5, 0xC4, 0xC2, 0xC7, 0xD0, 0x9A, 0x57, 0x7F, 0x2F, 0xBD, 0x3B,
0x95, 0x8B, 0xF4, 0xD5, 0xCB, 0x91, 0x3A, 0x01, 0xCD, 0x59, 0x16, 0x80, 0xDC, 0x52, 0x51, 0xF3,
0xC5, 0x6C, 0x45, 0x76, 0x32, 0x35, 0xC7, 0xB3, 0x5B, 0xD5, 0x24, 0xE6, 0xDC, 0x4C, 0xFD, 0xD9,
0xB3, 0x62, 0xB4, 0x1F, 0x4E, 0x98, 0x5F, 0xDE, 0xAF, 0xAD, 0x18, 0xCE, 0x6F, 0xB2, 0xB0, 0xFD,
0xBF, 0x61, 0xC0, 0xA2, 0x0A, 0xAF, 0xCC, 0x54, 0xBF, 0x8F, 0x29, 0xE7, 0x94, 0xE7, 0x2A, 0x6C,
0xF5, 0x61, 0x95, 0x6C, 0xE2, 0x42, 0x93, 0x3C, 0xD1, 0x50, 0xF9, 0x40, 0xCA, 0x4D, 0x15, 0xF3,
0xD4, 0xCF, 0x4F, 0xE0, 0xE4, 0x7F, 0x22, 0xD5, 0x84, 0x4B, 0xCC, 0xFC, 0x43, 0x0A, 0x8E, 0xEC,
0x6A, 0xF0, 0xC8, 0x50, 0xD8, 0x0F, 0xF0, 0xD0, 0x71, 0x81, 0x71, 0x09, 0x02, 0x66, 0xED, 0xD9,
0x2C, 0xAC, 0xE6, 0x95, 0x5E, 0xE6, 0x82, 0x63, 0x8E, 0xB1, 0x18, 0xC0, 0xBD, 0x42, 0x1B, 0x0C,
0x5E, 0x21, 0xB8, 0x9B, 0xC8, 0xF3, 0xA8, 0x72, 0xCF, 0x25, 0xF3, 0x9B, 0x77, 0xD8, 0xF9, 0xC1,
0xED, 0x14, 0xB6, 0x9C, 0x38, 0x25, 0xE0, 0x2A, 0xF5, 0xE8, 0x2F, 0xDB, 0xEB, 0x21, 0x46, 0xBA,
0x1D, 0x17, 0x01, 0x4B, 0x84, 0x22, 0x86, 0xAD, 0xA5, 0x11, 0x02, 0x24, 0xE8, 0x39, 0x20, 0x09,
0xA0, 0xC0, 0x11, 0x9A, 0xC5, 0x8F, 0x54, 0x10, 0x60, 0x83, 0xE1, 0xE5, 0xBE, 0x65, 0x86, 0x71,
0xF8, 0x16, 0x6D, 0x05, 0x42, 0xE6, 0xC7, 0x18, 0x63, 0x5F, 0x25, 0xE4, 0xF7, 0x1F, 0xF3, 0x2D,
0x13, 0x03, 0xC7, 0xF1, 0x6D, 0xCB, 0xC0, 0x01, 0x05, 0xDA, 0x89, 0x72, 0xB0, 0xAF, 0x46, 0xA0,
0x25, 0x8C, 0xEA, 0xD8, 0x8C, 0x97, 0x48, 0x52, 0x24, 0x43, 0x7E, 0x44, 0x6A, 0x3F, 0xC5, 0x36,
0xC0, 0xDB, 0x6D, 0x4C, 0x69, 0x8D, 0xC6, 0x2B, 0x31, 0x1A, 0xE8, 0x66, 0x3B, 0xD6, 0x3A, 0x26,
0xE5, 0xC9, 0x16, 0x29, 0x40, 0x56, 0xDF, 0xF6, 0xFF, 0x17, 0xFF, 0x9A, 0xDF, 0x5C, 0x40, 0xFB,
0x51, 0x82, 0xCF, 0x59, 0x38, 0x05, 0x6B, 0x55, 0xC6, 0x9F, 0x1F, 0x6A, 0x8B, 0x8C, 0x87, 0x43,
0xF6, 0xC3, 0xD5, 0xEE, 0xBA, 0x5D, 0xD6, 0xBB, 0xD1, 0x3D, 0x91, 0xE3, 0x2F, 0x72, 0xDF, 0x58,
0x04, 0x84, 0x80, 0x64, 0x57, 0x3C, 0x09, 0xD3, 0x81, 0x2D, 0x52, 0xF1, 0x9D, 0x0A, 0x3D, 0x4E,
0x0F, 0x0C, 0x55, 0xB4, 0xAD, 0x32, 0xD9, 0x98, 0x14, 0x42, 0x2D, 0x7B, 0x64, 0xDC, 0x06, 0xDD,
0x9D, 0xA2, 0xA5, 0x00, 0x42, 0x2B, 0x04, 0x6A, 0x76, 0xF2, 0x77, 0xB1, 0x69, 0xDD, 0x24, 0xC3,
0xE1, 0x0E, 0x3B, 0x7D, 0xB4, 0x15, 0x17, 0x6E, 0x41, 0xF6, 0x36, 0x2A, 0x53, 0x58, 0xF6, 0xD9,
0x47, 0x9A, 0x8B, 0x17, 0x57, 0x01, 0x32, 0x26, 0x9C, 0x15, 0x38, 0xD0, 0xE1, 0x66, 0xF9, 0x0A,
0xC5, 0x7C, 0x97, 0x0C, 0x26, 0xB3, 0x56, 0x4C, 0xBB, 0x1F, 0x7D, 0x92, 0xAB, 0xBA, 0xD1, 0x99,
0x44, 0x16, 0x97, 0x2F, 0x67, 0x20, 0x94, 0x95, 0x42, 0x71, 0xCA, 0xDE, 0xE2, 0xA3, 0x22, 0x8B,
0x74, 0x4B, 0xCB, 0x38, 0x79, 0xDF, 0x37, 0xCC, 0x1A, 0x78, 0x68, 0x10, 0x17, 0xE1, 0xFF, 0xEA,
0xEA, 0x41, 0xF3, 0x50, 0x97, 0x71, 0x7E, 0x76, 0xA4, 0xE4, 0xFB, 0x21, 0x03, 0x67, 0x73, 0xF6,
0x54, 0x81, 0xD6, 0x50, 0xCF, 0xE4, 0x18, 0xD0, 0x15, 0x13, 0x08, 0x76, 0x23, 0xE7, 0x4C, 0xE4,
0x63, 0x40, 0xEF, 0xFB, 0x9C, 0x7E, 0x04, 0x82, 0xD3, 0xE6, 0xCC, 0x14, 0x22, 0xD4, 0xE7, 0x98,
0x57, 0x55, 0x16, 0x04, 0xF7, 0x0A, 0xCE, 0x1E, 0x98, 0x56, 0x32, 0x71, 0xF2, 0xF2, 0xD8, 0x45,
0x37, 0xBF, 0x51, 0xBF, 0x88, 0x3A, 0xC5, 0xDF, 0x08, 0x54, 0xB9, 0xA8, 0x93, 0x2B, 0xDD, 0xA1,
0x4E, 0x03, 0xB1, 0x42, 0x92, 0xB8, 0x7B, 0xD9, 0x15, 0x05, 0x07, 0xD3, 0x0D, 0xFB, 0x65, 0x9F,
0x39, 0x32, 0xBA, 0x3D, 0x1E, 0x15, 0xEF, 0x66, 0x97, 0x62, 0x31, 0xB6, 0xFD, 0xFD, 0x76, 0xB7,
0x13, 0x0D, 0x9F, 0xF5, 0xD3, 0x7E, 0x11, 0xDE, 0xA6, 0x88, 0x12, 0x6A, 0x1C, 0x6B, 0xC8, 0x55
};

#define ANSWER 0x59123CD1

int main()
{
  bsg_set_tile_x_y();
  
  if (bsg_x == 0 && bsg_y == 0)
  {
    unsigned int crc = 0xffffffff;
    for (int i = 0; i < 2048; i++)
    {
      unsigned int idx = (crc ^ data[i]) & 0xff;
      crc = (crc >> 8) ^ table[idx];
    }
    crc = crc ^ 0xffffffff;
          

    if (crc == ANSWER)
    {
      bsg_printf("crc: %X [PASSED]\n", crc);
      bsg_finish_x(0);
    }
    else
    {
      bsg_printf("crc: %X [FAILED]\n", crc);
      bsg_fail_x(0);
    }
  }

  bsg_wait_while(1);
}

# FramStore 2.0.0 #

The library provides a class to help you to manage a set of FRAM chips (such as the as a single store. It will allow you to access your FRAMs through a single, combined address space.

Each FRAM’s storage is accessed at the byte level; each byte has a 16-bit address. The class supports writing to and reading from chips and store on a byte-by-byte basis. It also supports the writing of a blob to a chip or store, and multiple bytes can be read back into a blob. As such, the classes are a good partner for Electric Imp’s [serializer class](https://developer.electricimp.com/libraries/utilities/serializer), which converts Squirrel objects into binary data for storage. The *FramStore* class also supports writing and reading strings.

**To add this library to your project, add** `#require "FramStore.device.lib.nut:2.0.0"` **to the top of your device code**

## FramStore Usage ##

### Constructor: FramStore(*frams[, debug]*) ###

The constructor takes an array of up to eight objects representing individual FRAM chips. These objects may be *MB85RC* objects *(see above)* or some other object specifying a different type of FRAM chip.

The second parameter, *debug*, is optional: pass `true` to receive progress messages during various class methods.

If the constructor encounters an error during initialization, it will return `null` and post an error message to the log. Your code should check for a return value `null` before proceeding to use the FRAM store.

#### Example ####

```squirrel
#require "FramStore.device.lib.nut:2.0.0"
#require "MB85RC.class.nut:1.0.0"

// Configure I2C bus
local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

local f1 = MB85RC(i2c, 0xA0, 256);
local f2 = MB85RC(i2c, 0xA2, 256);

// Configure FRAM array with four devices
local store = FramStore([f1, f2]);
```

## FramStore Methods ##

### addFrams(*frams*) ###

This method allows you to add further FRAM chip objects to your store, up to a maximum of eight in total. These objects may be *MB85RC* objects *(see above)* or some other object specifying a different type of FRAM chip (but which has the same object interface).

Attempts to extend the total number of FRAM objects in the store beyond eight, either by adding a ninth or by, for example, adding an array of four FRAMs to a store that already contains six, will fail. Attempts to add FRAM chip objects that are already in the store will fail.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *frams* | Array | Yes | An array of one or more FRAM chip objects |

#### Returns ####

Boolean &mdash; whether the operation was successful (`true`) or not (`false`).

#### Example ####

```squirrel
local f3 = MB85RC(i2c, 0xA2, 256);
store.addFrams([f3]);
```

### clear(*value*) ###

This method clears the entire store to the specified *value*, an integer between 0x00 and 0xFF (255). 

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *value* | Integer | No | The value to write to all the store’s bytes. Default: 0x00 |

#### Returns ####

The instance &mdash; this.

#### Example ####

```squirrel
// Set the entire store to 0xAA
store.clear(0xAA);
```

### readByte(*address*) ###

This method reads and returns the unsigned 8-bit value located at *address* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

**Note** This method now returns the read value as an integer. This is a change of behavior from previous versions.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *address* | Integer | Yes | The store address from which to read |

#### Returns ####

Integer &mdash; The unsigned 8-bit value, or a negative integer indicating an error.

#### Example ####

```squirrel
local integerByte = store.readByte(0xFF01);
```

### writeByte(*address, value*) ###

This method writes the passed *value* to *address* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1. This value will also be returned of you attempt to write a *value* outside the 0&ndash;255 unsigned 8-bit range.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *address* | Integer | Yes | The store address at which to write |
| *value* | Integer | Yes | The value between 0x00 and 0xFF to write |

#### Returns ####

Integer &mdash; the write outcome as relayed by the FRAM chip object, eg. 0 for success, or a negative value for an error.

#### Example ####

```squirrel
local result = store.writeByte(0xFF01, 0xAA);
if (result == 0) {
    server.log("Value written");
} else {
    server.error("Value was not written");
}
```

### readBlob(*startAddress, numBytes*) ###

This method returns a blob containing the *numBytes* read from *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

If the attempt to fill the blob’s contents reaches the end of the store, the blob will be returned containing only the number of bytes that were actually read. So if the store size is 65535 bytes in size, and your code asks for the 512 bytes from address 65279, the returned blob will only be 256 bytes long.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *startAddress* | Integer | Yes | The store address at which to begin reading |
| *numBytes* | Integer | No | The number of bytes to read. Default: 1 |

#### Returns ####

Blob or integer &mdash; the read data, or a negative integer indicating an error.

### writeBlob(*startAddress, data[, wrap]*) ###

This method writes the passed blob, *data*, to *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1. The method can also be set to write at the start of the store any bytes which would otherwise be written beyond the store’s maximum address.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *startAddress* | Integer | Yes | The store address at which to begin writing |
| *data* | Blob | Yes | The blob to write |
| *wrap* | Boolean | No | Whether to write out-of-store bytes at the start of the store. Default: `false` |

#### Returns ####

The instance &mdash; *this* &mdash; or `null` if an error occurred.

### readString(*startAddress, numberOfChars*) ###

This method returns a string containing the *numberOfChars* characters read from *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

If the attempt to fill the blob’s contents reaches the end of the store, the blob will be returned containing only the number of bytes that were actually read. So if the store size is 65535 bytes in size, and your code asks for the 512 bytes from address 65279, the returned blob will only be 256 bytes long.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *startAddress* | Integer | Yes | The store address at which to begin reading |
| *numberOfChars* | Integer | No | The number of characters to read. Default: 1 |

#### Returns ####

String or integer &mdash; the read characters, or a negative integer indicating an error.

### writeString(*startAddress, chars[, wrap]*) ###

This method writes the passed string, *chars*, to *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

The third parameter, *wrap*, is optional and defaults to `false`. If *wrap* is set to `true`, then should there be an attempt to write data beyond the size of the store, then those overflow bytes will be written at the start of the store.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *startAddress* | Integer | Yes | The store address at which to begin writing |
| *chars* | String | Yes | The characters to write |
| *wrap* | Boolean | No | Whether to write out-of-store characters at the start of the store. Default: `false` |

#### Returns ####

The instance &mdash; *this* &mdash; or `null` if an error occurred.

### chipCount() ###

This method provides the number of FRAM chips that make up the store.

#### Returns ####

Integer &mdash; The number of FRAM chips that make up the store.

#### Example ####

```squirrel
function displayData(store, count = 64, chip = -1) {
    // Display the store (or chip) contents in the log
    local a = 0;
    local min = 0;
    local max = store.chipCount();

    if (block != -1) {
        min = block;
        max = block + 1;
    }

    for (local i = min; i < max; ++i) {
        server.log("Block: " + i);
        for (local j = 0 ; j < 32768 ; j += count) {
            local c = frams.framFromAddress(i * 32768);
            local s = "";
            for (local k = 0 ; k < count ; ++k) {
                local b = c.readByte(j + k);
                s += format("%d ", b[0]);
            }

            s = format("%04X - ", a) + s;
            server.log(s);
            a += count;
        }
    }
}
```

### maxAddress() ###

This method returns the chip’s top memory address. For example, if the chip has 64KB of storage (two 32KB FRAM chips), its 16-bit address space runs from 0x0000 to 0xFFFF. Calling *maxAddress()* will return 0xFFFF.

**Note** This behavior has changed from earlier versions of the library.

#### Returns ####

Integer &mdash; The store’s top address.

### framFromAddress(*address*) ###

This method returns the FRAM chip object which contains the store *address* passed. If the address is incorrectly specified, eg. it is beyond the size of the store, the method returns `null`.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *address* | Integer | Yes | An address within the store |

#### Returns ####

Object &mdash; A FRAM chip object, or `null` if an error occurred (eg. *address* out of range).

#### Example ####

See [*chipCount()*](#chipcount), above, for a usage example.

### framFromIndex(*index*) ###

This method returns the FRAM chip object at the specified index within the *FramStore* instance. If the index is out of range, the method returns `null`.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *index* | Integer | Yes | the index of a FRAM chip object within the store |

#### Returns ####

Object &mdash; A FRAM chip object, or `null` if an error occurred (eg. *index* out of range).

## License ##

This library is licensed under the [MIT License](https://github.com/electricimp/FramStore/blob/master/LICENSE).

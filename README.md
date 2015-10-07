# FramStore Library

The library provides a class to help you to manage a set of FRAM chips (such as the as a single store. It will allow you to access your FRAMs through a single, combined address space.

Each FRAM’s storage is accessed at the byte level; each byte has a 16-bit address. The class supports writing to and reading from chips and store on a byte-by-byte basis. It also supports the writing of a blob to a chip or store, and multiple bytes can be read back into a blob. As such, the classes are a good partner for Electric Imp’s [serializer class](https://electricimp.com/docs/libraries/utilities/), which converts Squirrel objects into binary data for storage. The *FramStore* class also supports writing and reading strings.

**To add this library to your project, add** `#require "FramStore.class.nut:1.0.0"` **to the top of your device code**

## FramStore Usage

### Constructor: FramStore(*frams*[, *debug*])

The constructor takes an array of up to eight objects representing individual FRAM chips. These objects may be *MB85RC* objects *(see above)* or some other object specifying a different type of FRAM chip.

The second parameter, *debug*, is optional: pass `true` to receive progress messages during various class methods.

If the constructor encounters an error during initialization, it will return `null` and post an error message to the log. Your code should check for a return value `null` before proceeding to use the FRAM store.

#### Example

```
#require "FramStore.class.nut:1.0.0"
#require "MB85RC.class.nut:1.0.0"

// Configure I2C bus
local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

local f1 = MB85RC(i2c, 0xA0, 256);
local f2 = MB85RC(i2c, 0xA2, 256);

// Configure FRAM array with four devices
local store = FramStore([f1, f2]);
```

## FramStore Methods

### addFrams(*frams*)

This method allows you to add further FRAM chip objects to your store, up to a maximum of eight. These objects may be *MB85RC* objects *(see above)* or some other object specifying a different type of FRAM chip. The objects are passed as an array into the parameter *frams*. 

Attempts to extend the number of FRAM objects in the store beyond eight, either by adding a ninth or by, for example, adding an array of four FRAMs to a store that already contains six, will fail.

#### Example

```
local f3 = MB85RC(i2c, 0xA2, 256);
store.addFrams([f3]);
```

### clear(*value*)

This method clears the entire store to the specified *value*, an integer between 0 and 255 (0xFF). By default, *value* is 0.

```
// Set the entire store to 0xAA
store.clear(0xAA);
```

### readByte(*address*)

This method reads and returns the unsigned 8-bit value located at *address** within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1, otherwise the byte value read from the store.

### writeByte(*address*, *value*)

This method writes the passed *value* to *address* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1. This value will also be returned of you attempt to write a *value* outside the 0&ndash;255 unsigned 8-bit range.

### readBlob(*startAddress*, *numBytes*)

This method returns a blob containing the *numBytes* read from *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

If the attempt to fill the blob’s contents reaches the end of the store, the blob will be returned containing only the number of bytes that were actually read. So if the store size is 65535 bytes in size, and your code asks for the 512 bytes from address 65279, the returned blob will only be 256 bytes long.

### writeBlob(*startAddress*, *blob*[, *wrap*])

This method writes the passed blob, *blob*, to *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

The third parameter, *wrap*, is optional and defaults to `false`. If *wrap* is set to `true`, then should there be an attempt to write data beyond the size of the store, then those overflow bytes will be written at the start of the store.

### readString(*startAddress*, *numChars*)

This method returns a string containing the *numChars* characters read from *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

If the attempt to fill the blob’s contents reaches the end of the store, the blob will be returned containing only the number of bytes that were actually read. So if the store size is 65535 bytes in size, and your code asks for the 512 bytes from address 65279, the returned blob will only be 256 bytes long.

### writeString(*startAddress*, *string*[, *wrap*])

This method writes the passed blob, *blob*, to *startAddress* within the store. The store’s capacity will depend on the number of FRAM chips it comprises. If the address is incorrectly specified for the current store, the method returns the value -1.

The third parameter, *wrap*, is optional and defaults to `false`. If *wrap* is set to `true`, then should there be an attempt to write data beyond the size of the store, then those overflow bytes will be written at the start of the store.

### chipCount()

This method returns the number of FRAM chips that make up the store.

#### Example

```
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
        for (local j = 0 ; j < 32768 ; j = j + count) {
            local c = frams.framFromAddress(i * 32768);
            local s = "";
            for (local k = 0 ; k < count ; ++k) {
                local b = c.readByte(j + k);
                s = s + format("%d ", b[0]);
            }

            s = format("%04X - ", a) + s;
            server.log(s);
            a = a + count;
        }
    }
}
```

### maxAddress()

This method returns the chip’s top memory address + 1. For example, if the chip has 64KB of storage (two 32KB FRAM chips), its 16-bit address space runs from 0x0000 to 0xFFFF. Calling *maxAddress()* will return 0x10000.
 
### framFromAddress(*address*)

This method returns the FRAM chip object which contains the store *address* passed. If the address is incorrectly specified, eg. it is beyond the size of the store, the method returns `null`.

See *chipCount()*, above, for a usage example.

### framFromIndex(*index*)

This method returns the FRAM chip object at the specified index within the *FramStore* instance. If the index is out of range, the method returns `null`.

## License

The FramStore library is licensed under the [MIT License](https://github.com/electricimp/FramStore/blob/master/LICENSE).

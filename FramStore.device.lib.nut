/**
 * A class that helps the user wrangle 1-8 separate MB85RC FRAM chips into a virtual FRAM unit with a single address space.
 *
 * Availibility Device
 * @author      Tony Smith (@smittytone)
 * @version     2.0.0
 * @license     MIT
 * @copyright   Electric Imp, Inc.
 *
 * @class
 *
 */
 class FramStore {
    
    /**
     * @property {string} VERSION - The library version
     * 
     */    
    static VERSION = "2.0.0";

    // Private properties
    _store = null;
    _chipCount = 0;
    _minAddress = 0;
    _maxAddress = 0;
    _debug = false;

    /**
     *  Initialize the FRAM store. Initial byte is always at address 0x00.
     *
     *  @constructor
     *
     *  @param {Array}   [frams]  - Array of MB85RC FRAM chip objects to be added to the store, up to a maximum of 8. Default: none.
     *  @param {Boolean} [debug ] - Set/unset to log/silence extra debug messages. Default: false
     *  
     *  @returns {instance} The instance
     *
     */
    constructor (frams = null, debug = false) {
        _chipCount = 0;
        _debug = debug;
        _store = [];

        // Note, frams == null is a valid configuration
        if (frams != null) {
            // Convert a single fram object to an array of len() 1
            if (typeof frams != "array") frams = [frams];

            // Make sure no more than 8 FRAM chips are included
            if (frams.len() > 8) throw "Misconstructed FRAM store: only 1-8 FRAM chip objects";

            local result = addFrams(frams);
        }
    }

    /**
     *  Add FRAM chip(s) to the array. Will fail if there are more than 8 chips before or after the operation.
     *
     *  @param {Array} frams - Array of FRAM chip objects to be added to the store, up to a maximum of 8. Default: none.
     *
     *  @returns {Boolean} Whether the FRAM chips were added (true) or not (false).  
     *
     */
    function addFrams(frams = null) {
        if (frams == null) {
            server.error("Framestore.addFrams(): You must pass a non-null FRAM chip object");
            return false;
        }

        if (_chipCount == 8) {
            // Maximum FRAMs added already
            server.error("Framestore.addFrams(): Cannot add more FRAM chips to store. Maximum of 8 already reached");
            return false;
        }

        // Convert single fram object to an array of len() 1
        if (typeof frams != "array") frams = [frams];

        if (frams.len() > 8 - _chipCount) {
            // Adding all the passed FRAMs will exceed the maximum chip coint (8)
            server.error("Framestore.addFrams(): Can only add " + (8 - _chipCount) + " more FRAM chips to store");
            return false;
        }

        // Attempt to each new chip to the store
        local addCount = 0;
        foreach (i, chip in frams) {
            local canAdd = true;
            local newFram = _newFram(chip);
            if (_store.len() > 0) {
                foreach (afram in _store) {
                    if (newFram.fram == afram.fram) {
                        // Chip has already been added to the store
                        canAdd = false;
                    }
                }   
            }
            if (canAdd) {
                _store.append(newFram);
                _chipCount++;
                addCount++;
                if (_debug) server.log(format("Adding FRAM %d at address 0x%04X", i, _store[i].startAddress));
            }
        }

        if (addCount == 0) {
            server.error("Framestore.addFrams(): No supplied FRAMs could be added - they are already in the store");
            return false;
        }

        return true;
    }

    /**
     *  Add FRAM chip(s) to the array. Will fail if there are more than 8 chips before or after the operation.
     *
     *  @param {Integer} [value] - 8-bit value to be written to each byte in the store. Bits above 7 are ignored. Default: 0x00.
     *
     *  @returns {this} The class instance.
     *
     */
    function clear(value = 0x00) {
        foreach (chip in _store) chip.fram.clear(value & 0xFF);
        return this;
    }

    /**
     *  Read and return the value of the byte at the specified store address.
     *
     *  @param {Integer} [address] - Numeric address of the required byte. Default: 0x00.
     *
     *  @returns {Integer} The unsigned 8-bit value, or -1 if an error occured, eg. invalid address.
     *
     */
    function readByte(address = 0x00) {
        if (address >= _maxAddress || address < 0) {
            server.error("Framestore.readByte(): Address out of range");
            return -1;
        }
        local block = _getBlock(address);
        local chip = framFromIndex(block);
        local subAddress = address - (block * (chip.csize() / 8) * 1024);
        
        // NOTE chip object's readByte() returns a single-character string, so convert to int
        local v = chip.readByte(subAddress);
        return v[0];
    }

    /**
     *  Read and return the value of the byte at the specified store address.
     *
     *  @param {Integer} [address] - Numeric address of the required byte. Default: 0x00.
     *  @param {Integer} [byte]    - 8-bit value to be written to each byte in the store. Default: 0x00.
     *
     *  @returns {Integer} Zero on on success, or a negative value if an error occured, eg. invalid address.
     *
     */
    function writeByte(address = 0x00, byte = 0x00) {
        // Calculates the specific FRAM address from the store address
        // and writes the specified byte there
        if (address >= _maxAddress || address < 0) {
            server.error("Framestore.writeByte(): Address out of range");
            return -1;
        }
        
        if (byte < 0 || byte > 0xFF) {
            server.error("Framestore.writeByte(): Data out of range");
            return -1;
        }
        local block = _getBlock(address);
        local chip = framFromIndex(block);
        local subAddress = address - (block * (chip.csize() / 8) * 1024);
        return chip.writeByte(subAddress, byte);
    }

    /**
     *  Read a specified number of bytes starting at the specified store address and return them as a blob.
     *
     *  @param {Integer} [startAddress] - Numeric address of the start of the required byte. Default: 0x00.
     *  @param {Integer} [numBytes]     - How many bytes to read. Default: 0x01.
     *
     *  @returns {Blob} The blob on success, or null if an error occured, eg. invalid address.
     *
     */
    function readBlob(startAddress = 0x00, numBytes = 0x01) {
        if (startAddress >= _maxAddress || startAddress < 0) {
            server.error("Framestore.readBlob(): Address out of range");
            return null;
        }

        if (numBytes < 1) {
            server.error("Framestore.readBlob(): Number of bytes must be greater than zero");
            return null;
        }

        local b = blob(numBytes);

        for (local i = 0 ; i < numBytes ; i++) {
            if (startAddress + i >= _maxAddress) {
                if (i > 0) {
                    b.seek(0, 'b');
                    return b.readblob(i);
                } else {
                    server.error("Framestore.readBlob(): Address out of range");
                    return null;
                }
            }
            
            local v = readByte(startAddress + i);
            
            if (v == -1) {
                server.error("Framestore.readBlob(): Read error");
                if (i > 0) {
                    b.seek(0, 'b');
                    return b.readblob(i);
                } else {
                    return null;
                }
            }
            
            b.writen(v, 'b');
        }

        return b;
    }

    /**
     *  Write a blob to the store starting at the specified store address.
     *
     *  @param {Integer} startAddress - Numeric store address of the byte at which the blob should start to be written.
     *  @param {Blob} data            - The data to write.
     *  @param {Boolean} [wrap]       - Whether to write out-of-store data at the start of the store. Default: false.
     *
     *  @returns {Instance} The class instance (this) on success, or null if an error occured, eg. invalid address.
     *
     */
    function writeBlob(startAddress = 0, data = null, wrap = false) {
        if (startAddress >= _maxAddress || startAddress < 0) {
            server.error("Framestore.writeBlob(): Address out of range");
            return null;
        }

        if (data == null) {
            server.error("Framestore.writeBlob(): You must provide valid data");
            return null;
        }

        data.seek(0, 'b');
        local end = startAddress + data.len();
        
        if (end < _maxAddress) {
            for (local i = startAddress ; i < end ; i++) {
                local r = writeByte(i, data.readn('b'));
                if (r != 0) {
                    server.error(format("Framestore.writeBlob(): Error writing data at 0x%04X", i));
                    return null;
                }
            }
        } else {
            // Write up to the end of the store
            for (local i = startAddress ; i < _maxAddress ; i++) {
                local r = writeByte(i, data.readn('b'));
                if (r != 0) {
                    server.error(format("Framestore.writeBlob(): Error writing data at 0x%04X", i));
                    return null;
                }
            }

            if (wrap) {
                // If wrap is true, write the remaining bytes at the start of the store
                local v = data.len() - data.tell();
                for (local i = 0 ; i < v ; i++) {
                    local r = writeByte(i, data.readn('b'));
                    if (r != 0) {
                        server.error(format("Framestore.writeBlob(): Error writing data at 0x%04X", i));
                        return null;
                    }
                }
            }
        }

        return this;
    }

    /**
     *  Read a specified number of characters starting at the specified store address and return them as a string.
     *
     *  @param {Integer} [startAddress] - Numeric address of the start of the required byte. Default: 0x00.
     *  @param {Integer} [numChars]     - How many characters to read. Default: 0x01.
     *
     *  @returns {String} The string on success, or null if an error occured, eg. invalid address.
     *
     */
    function readString(startAddress = 0x00, numChars = 0x01) {
        if (startAddress >= _maxAddress || startAddress < 0) {
            server.error("Framestore.readString(): Address out of range");
            return null;
        }
        if (numChars < 1)  {
            server.error("Framestore.readString(): Number of characters must be greater than zero");
            return null;
        }

        local s = "";
        
        for (local i = 0 ; i < numChars ; i++) {
            if (startAddress + i >= _maxAddress) {
                if (i > 0) {
                    break;
                } else {
                    server.error("Framestore.readString(): Address out of range");
                    return null;
                }
            }
            
            local v = readByte(startAddress + i);
            
            if (v == -1) {
                server.error("Framestore.readString(): Read error");
                if (i > 0) {
                    break;
                } else {
                    return null;
                }
            }

            s += v.tochar();
        }

        return s;
    }

    /**
     *  Write a string to the store starting at the specified store address.
     *
     *  @param {Integer} startAddress - Numeric store address of the byte at which the blob should start to be written.
     *  @param {Blob} string          - The string to write.
     *  @param {Boolean} [wrap]       - Whether to write out-of-store data at the start of the store. Default: false.
     *
     *  @returns {Instance} The class instance (this) on success, or null if an error occured, eg. invalid address.
     *
     */
    function writeString(startAddress = 0, chars = null, wrap = false) {
        // Writes the contents of a passed blob into the store at the
        // specified address. Only wraps data that exceeds the end of
        // the store if requested (lost otherwise)
        if (startAddress >= _maxAddress || startAddress < 0) {
            server.error("Framestore.writeString(): Address out of range");
            return null;
        }

        if (chars == null || chars.len() == 0) {
            server.error("Framestore.readString(): String must have more than zero characters");
            return null;
        }

        local end = startAddress + chars.len();

        if (end < _maxAddress) {
            for (local i = startAddress ; i < end ; i++) {
                local r = writeByte(i, chars[i - startAddress]);
                if (r != 0) {
                    server.error(format("Framestore.writeString(): Error writing data at 0x%04X", i));
                    return null;
                }
            }
        } else {
            // Write up to the end of the store
            local c = 0;
            for (local i = startAddress ; i < _maxAddress ; i++) {
                local r = writeByte(i, chars[i - startAddress]);
                if (r != 0) {
                    server.error(format("Framestore.writeString(): Error writing data at 0x%04X", i));
                    return null;
                }
                c++;
            }

            if (wrap) {
                // If wrap is true, write the remaining bytes
                // at the start of the store
                local v = chars.len() - c;
                for (local i = 0 ; i < v ; i++) {
                    local r = writeByte(i, chars[i + c]);
                    if (r != 0) {
                        server.error(format("Framestore.writeString(): Error writing data at 0x%04X", i));
                        return null;
                    }
                }
            }
        }
        
        return this;
    }

    /**
     *  Return the number of chips in the store.
     *
     *  @returns {Integer} The number of chips in the store.
     *
     */
    function chipCount() {
        return _chipCount;
    }

    /**
     *  Return the store's top address
     *
     *  @returns {Integer} The top address.
     *
     */
    function maxAddress() {
        return _maxAddress - 1;
    }

    /**
     *  Return a reference to the MB85RC FRAM chip object holding the specified store address.
     *
     *  @param {Integer} [address] - Numeric store address. Default: 0x00.
     *
     *  @returns {MB85RC} The MB85RC instance on success, or null if an error occured, eg. invalid address.
     *
     */
    function framFromAddress(address = 0x00) {
        if (address < 0 || address >= _maxAddress) {
            server.error("FramStore.framFromAddress(): Address out of range");
            return null;
        }

        local block = address / 32768;
        return _store[block].fram;
    }

    /**
     *  Return a reference to the MB85RC FRAM chip object holding the specified store array index.
     *
     *  @param {Integer} [index] - Numeric store array index. Default: 0x00.
     *
     *  @returns {MB85RC} The MB85RC instance on success, or null if an error occured, eg. invalid address.
     *
     */
    function framFromIndex(index = 0) {
        if (index < 0 || index >= _chipCount) {
            server.error("FramStore.framFromIndex(): Index out of range");
            return null;
        }

        return _store[index].fram;
    }

    // PRIVATE FUNCTIONS

    /**
     *  Return the index in the store array of the fram object which contains the specified store address.
     *
     *  @param {Integer} addr - Numeric store address.
     *
     *  @returns {MB85RC} The index of the required chip in the array, or -1 on an error.
     *
     *  @private
     *
     */
    function _getBlock(addr) {
        for (local i = 0 ; i < _store.len() ; i++) {
            local f = _store[i];
            if (addr >= f.startAddress && addr <= f.endAddress) return i;
        }

        return -1;
    }

    /**
     * MB85RC chip descriptor
     *
     * @typedef {table} chipDesc
     *
     * @property {Integer} startAddress - The store address of the first byte in the chip's own store.
     * @property {Integer} endAddress   - The store address of the last byte in the chip's own store.
     * @property {MB85RC}  fram         - The MB85RC object representing the chip.
     *
     */

    /**
     *  Create a new FRAM chip record and add it to the store array
     *
     *  @param {MB85RC} chip - The MB85RC object representing the chip.
     *
     *  @returns {chipDesc} The new chip descriptor.
     *
     *  @private
     *
     */
    function _newFram(chip) {
        local newFram = {};
        newFram.startAddress <- _maxAddress;
        _maxAddress = _maxAddress + chip.maxAddress();
        newFram.endAddress <- _maxAddress - 1;
        newFram.fram <- chip;
        return newFram;
    }
}

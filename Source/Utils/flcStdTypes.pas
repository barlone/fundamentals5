{******************************************************************************}
{                                                                              }
{   Library:          Fundamentals 5.00                                        }
{   File name:        flcStdTypes.pas                                          }
{   File version:     5.02                                                     }
{   Description:      Standard type definitions.                               }
{                                                                              }
{   Copyright:        Copyright (c) 2000-2018, David J Butler                  }
{                     All rights reserved.                                     }
{                     Redistribution and use in source and binary forms, with  }
{                     or without modification, are permitted provided that     }
{                     the following conditions are met:                        }
{                     Redistributions of source code must retain the above     }
{                     copyright notice, this list of conditions and the        }
{                     following disclaimer.                                    }
{                     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND   }
{                     CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED          }
{                     WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED   }
{                     WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A          }
{                     PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL     }
{                     THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,    }
{                     INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR             }
{                     CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,    }
{                     PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF     }
{                     USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)         }
{                     HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER   }
{                     IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING        }
{                     NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE   }
{                     USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE             }
{                     POSSIBILITY OF SUCH DAMAGE.                              }
{                                                                              }
{   Github:           https://github.com/fundamentalslib                       }
{   E-mail:           fundamentals.library at gmail.com                        }
{                                                                              }
{ Revision history:                                                            }
{                                                                              }
{   2000-       1.01  Initial versions                                         }
{   2018/07/11  5.02  Move to flcStdTypes unit from flcUtils.                  }
{                                                                              }
{ Supported compilers:                                                         }
{                                                                              }
{   Delphi 10 Win32                     5.02  2016/01/09                       }
{                                                                              }
{******************************************************************************}

{$INCLUDE ..\flcInclude.inc}

{$IFDEF FREEPASCAL}
  {$WARNINGS OFF}
  {$HINTS OFF}
{$ENDIF}

{$IFDEF DEBUG}
{$IFDEF TEST}
  {$DEFINE STDTYPES_TEST}
{$ENDIF}
{$ENDIF}

unit flcStdTypes;

interface



{                                                                              }
{ Integer types                                                                }
{                                                                              }
type
  Int8      = ShortInt;
  Int16     = SmallInt;
  Int32     = LongInt;

  UInt8     = Byte;
  UInt16    = Word;
  {$IFDEF SupportFixedUInt}
  UInt32    = FixedUInt;
  {$ELSE}
  UInt32    = LongWord;
  {$ENDIF}
  {$IFNDEF SupportUInt64}
  UInt64    = type Int64;
  {$ENDIF}

  Word8     = UInt8;
  Word16    = UInt16;
  Word32    = UInt32;
  Word64    = UInt64;

  {$IFNDEF SupportNativeInt}
  {$IFDEF CPU_X86_64}
  NativeInt   = type Int64;
  {$ELSE}
  NativeInt   = type Integer;
  {$ENDIF}
  PNativeInt  = ^NativeInt;
  {$ENDIF}
  {$IFDEF FREEPASCAL}
  PNativeInt  = ^NativeInt;
  {$ENDIF}
  {$IFDEF DELPHI2010}
  PNativeInt  = ^NativeInt;
  {$ENDIF}

  {$IFNDEF SupportNativeUInt}
  {$IFDEF CPU_X86_64}
  NativeUInt  = type Word64;
  {$ELSE}
  NativeUInt  = type Cardinal;
  {$ENDIF}
  PNativeUInt = ^NativeUInt;
  {$ENDIF}
  {$IFDEF FREEPASCAL}
  PNativeUInt = ^NativeUInt;
  {$ENDIF}
  {$IFDEF DELPHI2010}
  PNativeUInt = ^NativeUInt;
  {$ENDIF}

  {$IFDEF DELPHI5_DOWN}
  PByte       = ^Byte;
  PWord       = ^Word;
  PLongWord   = ^LongWord;
  PShortInt   = ^ShortInt;
  PSmallInt   = ^SmallInt;
  PLongInt    = ^LongInt;
  PInteger    = ^Integer;
  PInt64      = ^Int64;
  {$ENDIF}

  PInt8     = ^Int8;
  PInt16    = ^Int16;
  PInt32    = ^Int32;

  PWord8    = ^Word8;
  PWord16   = ^Word16;
  PWord32   = ^Word32;

  PUInt8    = ^UInt8;
  PUInt16   = ^UInt16;
  PUInt32   = ^UInt32;
  PUInt64   = ^UInt64;

  {$IFNDEF ManagedCode}
  SmallIntRec = packed record
    case Integer of
      0 : (Lo, Hi : Byte);
      1 : (Bytes  : array[0..1] of Byte);
  end;

  LongIntRec = packed record
    case Integer of
      0 : (Lo, Hi : Word);
      1 : (Words  : array[0..1] of Word);
      2 : (Bytes  : array[0..3] of Byte);
  end;
  PLongIntRec = ^LongIntRec;
  {$ENDIF}

const
  MinByte       = Low(Byte);
  MaxByte       = High(Byte);
  MinWord       = Low(Word);
  MaxWord       = High(Word);
  MinShortInt   = Low(ShortInt);
  MaxShortInt   = High(ShortInt);
  MinSmallInt   = Low(SmallInt);
  MaxSmallInt   = High(SmallInt);
  MinLongWord   = LongWord(Low(LongWord));
  MaxLongWord   = LongWord(High(LongWord));
  MinLongInt    = LongInt(Low(LongInt));
  MaxLongInt    = LongInt(High(LongInt));
  MinInt64      = Int64(Low(Int64));
  MaxInt64      = Int64(High(Int64));
  MinInteger    = Integer(Low(Integer));
  MaxInteger    = Integer(High(Integer));
  MinCardinal   = Cardinal(Low(Cardinal));
  MaxCardinal   = Cardinal(High(Cardinal));
  MinNativeUInt = NativeUInt(Low(NativeUInt));
  MaxNativeUInt = NativeUInt(High(NativeUInt));
  MinNativeInt  = NativeInt(Low(NativeInt));
  MaxNativeInt  = NativeInt(High(NativeInt));

const
  BitsPerByte       = 8;
  BitsPerLongWord   = SizeOf(LongWord) * 8;
  NativeWordSize    = SizeOf(NativeInt);
  BitsPerNativeWord = NativeWordSize * 8;



{                                                                              }
{ Boolean types                                                                }
{                                                                              }
type
  Bool8     = ByteBool;
  Bool16    = WordBool;
  Bool32    = LongBool;

  {$IFDEF DELPHI5_DOWN}
  PBoolean  = ^Boolean;
  PByteBool = ^ByteBool;
  PWordBool = ^WordBool;
  {$ENDIF}
  {$IFNDEF FREEPASCAL}
  PLongBool = ^LongBool;
  {$ENDIF}

  PBool8    = ^Bool8;
  PBool16   = ^Bool16;
  PBool32   = ^Bool32;



{                                                                              }
{ Real number types                                                            }
{                                                                              }
type
  {$IFDEF DELPHI5_DOWN}
  PSingle   = ^Single;
  PDouble   = ^Double;
  PExtended = ^Extended;
  {$ENDIF}

  {$IFNDEF ManagedCode}
  {$IFNDEF ExtendedIsDouble}
  ExtendedRec = packed record
    case Boolean of
      True: (
        Mantissa : packed array[0..1] of LongWord; { MSB of [1] is the normalized 1 bit }
        Exponent : Word;                           { MSB is the sign bit                }
      );
      False: (Value: Extended);
  end;
  {$ENDIF}
  {$ENDIF}

  Float32 = Single;
  Float64 = Double;
  {$IFNDEF ExtendedIsDouble}
  Float80 = Extended;
  {$ENDIF}

  PFloat32 = ^Float32;
  PFloat64 = ^Float64;
  {$IFNDEF ExtendedIsDouble}
  PFloat80 = ^Float80;
  {$ENDIF}

  {$IFDEF ExtendedIsDouble}
  Float = Double;
  {$DEFINE FloatIsDouble}
  {$ELSE}
  Float = Extended;
  {$DEFINE FloatIsExtended}
  {$ENDIF}
  PFloat = ^Float;

const
  MinSingle   : Single   = 1.5E-45;
  MaxSingle   : Single   = 3.4E+38;
  MinDouble   : Double   = 5.0E-324;
  MaxDouble   : Double   = 1.7E+308;
  {$IFDEF ExtendedIsDouble}
  MinExtended : Extended = 5.0E-324;
  MaxExtended : Extended = 1.7E+308;
  {$ELSE}
  MinExtended : Extended = 3.4E-4932;
  MaxExtended : Extended = 1.1E+4932;
  {$ENDIF}

{$IFNDEF ManagedCode}
{$IFNDEF ExtendedIsDouble}
const
  ExtendedNan      : ExtendedRec = (Mantissa:($FFFFFFFF, $FFFFFFFF); Exponent:$7FFF);
  ExtendedInfinity : ExtendedRec = (Mantissa:($00000000, $80000000); Exponent:$7FFF);
{$ENDIF}
{$ENDIF}

{$IFDEF SupportCurrency}
{$IFDEF DELPHI5_DOWN}
type
  PCurrency = ^Currency;
{$ENDIF}

{$IFNDEF CLR}
const
  MinCurrency : Currency = -922337203685477.5807;
  MaxCurrency : Currency = 922337203685477.5807;
{$ENDIF}
{$ENDIF}



{                                                                              }
{ Pointer                                                                      }
{                                                                              }
{$IFDEF DELPHI5_DOWN}
type
  PPointer = ^Pointer;
{$ENDIF}



{                                                                              }
{ String types                                                                 }
{                                                                              }



{                                                                              }
{ AnsiString                                                                   }
{   AnsiChar is a byte size character.                                         }
{   AnsiString is a reference counted, code page aware, byte string.           }
{                                                                              }
{$IFNDEF SupportAnsiChar}
type
  AnsiChar = Byte;
  PAnsiChar = ^AnsiChar;
{$DEFINE AnsiCharIsOrd}
{$ENDIF}



{                                                                              }
{ RawByteString                                                                }
{   RawByteString is an alias for AnsiString where all bytes are raw bytes     }
{   that do not undergo any character set translation.                         }
{   Under Delphi 2009 RawByteString is defined as "type AnsiString($FFFF)".    }
{                                                                              }
type
  RawByteChar = AnsiChar;
  PRawByteChar = ^RawByteChar;
  {$IFDEF SupportRawByteString}
  {$IFDEF FREEPASCAL}
  PRawByteString = ^RawByteString;
  {$ENDIF}
  {$ENDIF}
  RawByteCharSet = set of RawByteChar;



{                                                                              }
{ UTF8String                                                                   }
{   UTF8String is a variable character length encoding for Unicode strings.    }
{   For Ascii values, a UTF8String is the same as a AsciiString.               }
{   Under Delphi 2009 UTF8String is defined as "type AnsiString($FDE9)"        }
{                                                                              }
{$IFNDEF SupportUTF8String}
type
  UTF8Char = AnsiChar;
  PUTF8Char = ^UTF8Char;
{$ENDIF}



{                                                                              }
{ WideString                                                                   }
{   WideChar is a 16-bit character.                                            }
{   WideString is not reference counted.                                       }
{                                                                              }
{$IFNDEF SupportWideChar}
type
  WideChar = Word;
  PWideChar = ^WideChar;
{$DEFINE WideCharIsOrd}
{$ENDIF}

type
  TWideCharMatchFunction = function (const Ch: WideChar): Boolean;



{                                                                              }
{ UnicodeString                                                                }
{   UnicodeString in Delphi 2009 is reference counted, code page aware,        }
{   variable character length unicode string. Defaults to UTF-16 encoding.     }
{                                                                              }
type
  UnicodeChar = WideChar;
  PUnicodeChar = ^UnicodeChar;



{                                                                              }
{ UCS4String                                                                   }
{   UCS4Char is a 32-bit character from the Unicode character set.             }
{   UCS4String is a reference counted string of UCS4Char characters.           }
{                                                                              }
{$IFNDEF SupportUCS4String}
type
  UCS4Char = LongWord;
  PUCS4Char = ^UCS4Char;
{$ENDIF}



{                                                                              }
{ Sets                                                                         }
{                                                                              }
type
  CharSet = set of AnsiChar;
  AnsiCharSet = CharSet;
  ByteSet = set of Byte;

  PCharSet = ^CharSet;
  PByteSet = ^ByteSet;



{                                                                              }
{ Dynamic arrays                                                               }
{                                                                              }
type
  ByteArray = array of Byte;
  WordArray = array of Word;
  LongWordArray = array of LongWord;
  CardinalArray = LongWordArray;
  NativeUIntArray = array of NativeUInt;
  ShortIntArray = array of ShortInt;
  SmallIntArray = array of SmallInt;
  LongIntArray = array of LongInt;
  IntegerArray = LongIntArray;
  NativeIntArray = array of NativeInt;
  Int64Array = array of Int64;
  SingleArray = array of Single;
  DoubleArray = array of Double;
  ExtendedArray = array of Extended;
  CurrencyArray = array of Currency;
  BooleanArray = array of Boolean;
  AnsiStringArray = array of AnsiString;
  RawByteStringArray = array of RawByteString;
  WideStringArray = array of WideString;
  UnicodeStringArray = array of UnicodeString;
  StringArray = array of String;
  {$IFNDEF ManagedCode}
  PointerArray = array of Pointer;
  {$ENDIF}
  ObjectArray = array of TObject;
  InterfaceArray = array of IInterface;
  CharSetArray = array of CharSet;
  ByteSetArray = array of ByteSet;



{                                                                              }
{ TBytes                                                                       }
{   TBytes is a dynamic array of bytes.                                        }
{                                                                              }
{$IFNDEF TBytesDeclared}
type
  TBytes = array of Byte;
{$ENDIF}



{                                                                              }
{ Array pointers                                                               }
{                                                                              }

{ Maximum array elements                                                       }
const
  MaxArraySize = $7FFFFFFF; // 2 Gigabytes
  MaxByteArrayElements = MaxArraySize div Sizeof(Byte);
  MaxWordArrayElements = MaxArraySize div Sizeof(Word);
  MaxLongWordArrayElements = MaxArraySize div Sizeof(LongWord);
  MaxCardinalArrayElements = MaxArraySize div Sizeof(Cardinal);
  MaxNativeUIntArrayElements = MaxArraySize div Sizeof(NativeUInt);
  MaxShortIntArrayElements = MaxArraySize div Sizeof(ShortInt);
  MaxSmallIntArrayElements = MaxArraySize div Sizeof(SmallInt);
  MaxLongIntArrayElements = MaxArraySize div Sizeof(LongInt);
  MaxIntegerArrayElements = MaxArraySize div Sizeof(Integer);
  MaxInt64ArrayElements = MaxArraySize div Sizeof(Int64);
  MaxNativeIntArrayElements = MaxArraySize div Sizeof(NativeInt);
  MaxSingleArrayElements = MaxArraySize div Sizeof(Single);
  MaxDoubleArrayElements = MaxArraySize div Sizeof(Double);
  MaxExtendedArrayElements = MaxArraySize div Sizeof(Extended);
  MaxBooleanArrayElements = MaxArraySize div Sizeof(Boolean);
  {$IFNDEF CLR}
  MaxCurrencyArrayElements = MaxArraySize div Sizeof(Currency);
  MaxAnsiStringArrayElements = MaxArraySize div Sizeof(AnsiString);
  MaxRawByteStringArrayElements = MaxArraySize div Sizeof(RawByteString);
  MaxWideStringArrayElements = MaxArraySize div Sizeof(WideString);
  MaxUnicodeStringArrayElements = MaxArraySize div Sizeof(UnicodeString);
  {$IFDEF StringIsUnicode}
  MaxStringArrayElements = MaxArraySize div Sizeof(UnicodeString);
  {$ELSE}
  MaxStringArrayElements = MaxArraySize div Sizeof(AnsiString);
  {$ENDIF}
  MaxPointerArrayElements = MaxArraySize div Sizeof(Pointer);
  MaxObjectArrayElements = MaxArraySize div Sizeof(TObject);
  MaxInterfaceArrayElements = MaxArraySize div Sizeof(IInterface);
  MaxCharSetArrayElements = MaxArraySize div Sizeof(CharSet);
  MaxByteSetArrayElements = MaxArraySize div Sizeof(ByteSet);
  {$ENDIF}

{ Static array types                                                           }
type
  TStaticByteArray = array[0..MaxByteArrayElements - 1] of Byte;
  TStaticWordArray = array[0..MaxWordArrayElements - 1] of Word;
  TStaticLongWordArray = array[0..MaxLongWordArrayElements - 1] of LongWord;
  TStaticNativeUIntArray = array[0..MaxNativeUIntArrayElements - 1] of NativeUInt;
  TStaticShortIntArray = array[0..MaxShortIntArrayElements - 1] of ShortInt;
  TStaticSmallIntArray = array[0..MaxSmallIntArrayElements - 1] of SmallInt;
  TStaticLongIntArray = array[0..MaxLongIntArrayElements - 1] of LongInt;
  TStaticInt64Array = array[0..MaxInt64ArrayElements - 1] of Int64;
  TStaticNativeIntArray = array[0..MaxNativeIntArrayElements - 1] of NativeInt;
  TStaticSingleArray = array[0..MaxSingleArrayElements - 1] of Single;
  TStaticDoubleArray = array[0..MaxDoubleArrayElements - 1] of Double;
  TStaticExtendedArray = array[0..MaxExtendedArrayElements - 1] of Extended;
  TStaticBooleanArray = array[0..MaxBooleanArrayElements - 1] of Boolean;
  {$IFNDEF CLR}
  TStaticCurrencyArray = array[0..MaxCurrencyArrayElements - 1] of Currency;
  TStaticAnsiStringArray = array[0..MaxAnsiStringArrayElements - 1] of AnsiString;
  TStaticRawByteStringArray = array[0..MaxRawByteStringArrayElements - 1] of RawByteString;
  TStaticWideStringArray = array[0..MaxWideStringArrayElements - 1] of WideString;
  TStaticUnicodeStringArray = array[0..MaxUnicodeStringArrayElements - 1] of UnicodeString;
  {$IFDEF StringIsUnicode}
  TStaticStringArray = TStaticUnicodeStringArray;
  {$ELSE}
  TStaticStringArray = TStaticAnsiStringArray;
  {$ENDIF}
  TStaticPointerArray = array[0..MaxPointerArrayElements - 1] of Pointer;
  TStaticObjectArray = array[0..MaxObjectArrayElements - 1] of TObject;
  TStaticInterfaceArray = array[0..MaxInterfaceArrayElements - 1] of IInterface;
  TStaticCharSetArray = array[0..MaxCharSetArrayElements - 1] of CharSet;
  TStaticByteSetArray = array[0..MaxByteSetArrayElements - 1] of ByteSet;
  {$ENDIF}
  TStaticCardinalArray = TStaticLongWordArray;
  TStaticIntegerArray = TStaticLongIntArray;

{ Static array pointers                                                        }
type
  PStaticByteArray = ^TStaticByteArray;
  PStaticWordArray = ^TStaticWordArray;
  PStaticLongWordArray = ^TStaticLongWordArray;
  PStaticCardinalArray = ^TStaticCardinalArray;
  PStaticNativeUIntArray = ^TStaticNativeUIntArray;
  PStaticShortIntArray = ^TStaticShortIntArray;
  PStaticSmallIntArray = ^TStaticSmallIntArray;
  PStaticLongIntArray = ^TStaticLongIntArray;
  PStaticIntegerArray = ^TStaticIntegerArray;
  PStaticInt64Array = ^TStaticInt64Array;
  PStaticNativeIntArray = ^TStaticNativeIntArray;
  PStaticSingleArray = ^TStaticSingleArray;
  PStaticDoubleArray = ^TStaticDoubleArray;
  PStaticExtendedArray = ^TStaticExtendedArray;
  PStaticBooleanArray = ^TStaticBooleanArray;
  {$IFNDEF CLR}
  PStaticCurrencyArray = ^TStaticCurrencyArray;
  PStaticAnsiStringArray = ^TStaticAnsiStringArray;
  PStaticRawByteStringArray = ^TStaticRawByteStringArray;
  PStaticWideStringArray = ^TStaticWideStringArray;
  PStaticUnicodeStringArray = ^TStaticUnicodeStringArray;
  PStaticStringArray = ^TStaticStringArray;
  PStaticPointerArray = ^TStaticPointerArray;
  PStaticObjectArray = ^TStaticObjectArray;
  PStaticInterfaceArray = ^TStaticInterfaceArray;
  PStaticCharSetArray = ^TStaticCharSetArray;
  PStaticByteSetArray = ^TStaticByteSetArray;
  {$ENDIF}



implementation



end.
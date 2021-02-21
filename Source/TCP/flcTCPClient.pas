{******************************************************************************}
{                                                                              }
{   Library:          Fundamentals 5.00                                        }
{   File name:        flcTCPClient.pas                                         }
{   File version:     5.28                                                     }
{   Description:      TCP client.                                              }
{                                                                              }
{   Copyright:        Copyright (c) 2007-2021, David J Butler                  }
{                     All rights reserved.                                     }
{                     This file is licensed under the BSD License.             }
{                     See http://www.opensource.org/licenses/bsd-license.php   }
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
{   2008/08/15  0.01  Initial development.                                     }
{   2010/11/07  0.02  Revision.                                                }
{   2010/11/12  0.03  Refactor for asynchronous operation.                     }
{   2010/12/02  0.04  TLS support.                                             }
{   2010/12/20  0.05  Various enhancements.                                    }
{   2011/04/22  0.06  Thread safe Start/Stop.                                  }
{   2011/06/18  0.07  IsConnected, IsConnectionClosed, etc.                    }
{   2011/06/25  0.08  Improved logging.                                        }
{   2011/09/03  4.09  Revise for Fundamentals 4.                               }
{   2011/09/10  4.10  Synchronised events option.                              }
{   2011/10/06  4.11  Remove wait condition on startup.                        }
{   2011/11/07  4.12  Allow client to be restarted after being stopped.        }
{                     Added WaitForStartup property to optionally enable       }
{                     waiting for thread initialisation.                       }
{   2015/04/26  4.13  Blocking interface and worker thread.                    }
{   2015/04/27  4.14  Options to retry failed connections.                     }
{   2016/01/09  5.15  Revised for Fundamentals 5.                              }
{   2018/07/19  5.16  ReconnectOnDisconnect property.                          }
{   2018/08/30  5.17  Close socket before thread shutdown to prevent blocking. }
{   2018/09/01  5.18  Handle client stopping in process thread.                }
{   2018/12/31  5.19  OnActivity events.                                       }
{   2019/04/10  5.20  Locking changes.                                         }
{   2019/04/16  5.21  Shutdown events.                                         }
{   2019/10/05  5.22  Select wait in Process thread.                           }
{   2020/03/28  5.23  Select wait 50ms under Win32.                            }
{   2020/05/02  5.24  Log exceptions raised in event handlers.                 }
{   2020/05/11  5.25  TLS options.                                             }
{   2020/07/25  5.26  Change event order to: Active, Start, Stop, Inactive.    }
{   2020/07/25  5.27  WaitForStartup using TSimpleEvent. StartFailed state.    }
{   2020/07/26  5.28  Remove SynchronisedEvents. Add OnReadyFailed event.      }
{                                                                              }
{ Supported compilers:                                                         }
{                                                                              }
{   Delphi 2010-10.4 Win32/Win64        5.25  2020/06/02                       }
{   Delphi 10.2-10.3 Win32/Win64        5.28  2020/07/30                       }
{   Delphi 10.2 Linux64                 5.28  2020/07/30                       }
{   Delphi 10.3-10.4 Linux64            5.25  2020/06/02                       }
{   Delphi 10.2-10.4 iOS32/64           5.25  2020/06/02                       }
{   Delphi 10.2-10.4 OSX32/64           5.25  2020/06/02                       }
{   Delphi 10.2-10.4 Android32/64       5.25  2020/06/02                       }
{   FreePascal 3.0.4 Win64              5.25  2020/06/02                       }
{                                                                              }
{******************************************************************************}

{$INCLUDE ..\flcInclude.inc}
{$INCLUDE flcTCP.inc}

unit flcTCPClient;

interface

uses
  { System }

  {$IFDEF OS_MSWIN}
  Messages,
  Windows,
  {$ENDIF}

  SysUtils,
  SyncObjs,
  Classes,

  flcStdTypes,

  { Sockets }

  flcSocketLib,
  flcSocket,

  { TCP }

  flcTCPUtils,
  flcTCPConnection

  { Socks }

  {$IFDEF TCPCLIENT_SOCKS},
  flcSocksClient
  {$ENDIF}

  { TLS }

  {$IFDEF TCPCLIENT_TLS},
  flcTLSConsts,
  flcTLSTransportTypes,
  flcTLSTransportConnection,
  flcTLSTransportClient
  {$ENDIF}

  { WebSocket }

  {$IFDEF TCPCLIENT_WEBSOCKET},
  flcWebSocketUtils,
  flcWebSocketConnection,
  flcWebSocketClient
  {$ENDIF}
  ;



{                                                                              }
{ TCP Client                                                                   }
{                                                                              }
type
  ETCPClient = class(Exception);

  TTCPClientState = (
    csInit,           // Client initialise
    csStarting,       // Client starting (thread starting up)
    csStartFailed,    // Client start failed
    csStarted,        // Client activated (thread running)
    csConnectRetry,   // Client retrying connection
    csResolvingLocal, // Local IP resolving
    csResolvedLocal,  // Local IP resolved
    csBound,          // Local IP bound
    csResolving,      // IP resolving
    csResolved,       // IP resolved
    csConnecting,     // TCP connecting
    csConnected,      // TCP connected
    csNegotiating,    // Connection proxy negotiation
    csReadyFailed,    // Failed to reach ready state
    csReady,          // Client ready, connection negotiated and ready
    //// csReadyClose
    csClosed,         // Connection closed
    //// csFinishedClose
    //// csFinishedError
    csStopped         // Client stopped
    );

  TTCPClientStates = set of TTCPClientState;

  TTCPClientLogType = (
    cltDebug,
    cltParameter, ////
    cltInfo,
    cltError
    );

  TTCPClientAddressFamily = (
    cafIP4,
    cafIP6
    );

{$IFDEF TCPCLIENT_TLS}
type
  TTCPClientTLSOption = (
    ctoNone
    );

  TTCPClientTLSOptions = set of TTCPClientTLSOption;

const
  DefaultTCPClientTLSOptions = [];

type
  TTCPClientTLSClientOptions      = TTLSClientOptions;
  TTCPClientTLSVersionOptions     = TTLSVersionOptions;
  TTCPClientTLSKeyExchangeOptions = TTLSKeyExchangeOptions;
  TTCPClientTLSCipherOptions      = TTLSCipherOptions;
  TTCPClientTLSHashOptions        = TTLSHashOptions;
{$ENDIF}

const
  DefaultTCPClientStartupTimeout = 30000; // 30s

type
  TF5TCPClient = class;

  TTCPClientNotifyEvent = procedure (AClient: TF5TCPClient) of object;
  TTCPClientLogEvent = procedure (AClient: TF5TCPClient; LogType: TTCPClientLogType; Msg: String; LogLevel: Integer) of object;
  TTCPClientStateEvent = procedure (AClient: TF5TCPClient; AState: TTCPClientState) of object;
  TTCPClientErrorEvent = procedure (AClient: TF5TCPClient; ErrorMsg: String; ErrorCode: Integer) of object;
  TTCPClientWorkerExecuteEvent = procedure (AClient: TF5TCPClient; AConnection: TTCPBlockingConnection; var CloseOnExit: Boolean) of object;

  TTCPClientProcessThread = class(TThread)
  protected
    FTCPClient : TF5TCPClient;
    procedure Execute; override;
  public
    constructor Create(const ATCPClient: TF5TCPClient);
    property Terminated;
  end;

  TF5TCPClient = class(TComponent)
  protected
    // parameters
    FAddressFamily      : TTCPClientAddressFamily;
    FHost               : String;
    FPort               : String;
    FLocalHost          : String;
    FLocalPort          : String;

    FRetryFailedConnect            : Boolean;
    FRetryFailedConnectDelaySec    : Integer;
    FRetryFailedConnectMaxAttempts : Integer;
    FReconnectOnDisconnect         : Boolean;

    {$IFDEF TCPCLIENT_SOCKS}
    FSocksEnabled       : Boolean;
    FSocksHost          : RawByteString;
    FSocksPort          : RawByteString;
    FSocksAuth          : Boolean;
    FSocksUsername      : RawByteString;
    FSocksPassword      : RawByteString;
    {$ENDIF}

    {$IFDEF TCPCLIENT_TLS}
    FTLSEnabled            : Boolean;
    FTLSOptions            : TTCPClientTLSOptions;
    FTLSClientOptions      : TTCPClientTLSClientOptions;
    FTLSVersionOptions     : TTCPClientTLSVersionOptions;
    FTLSKeyExchangeOptions : TTCPClientTLSKeyExchangeOptions;
    FTLSCipherOptions      : TTCPClientTLSCipherOptions;
    FTLSHashOptions        : TTCPClientTLSHashOptions;
    {$ENDIF}

    {$IFDEF TCPCLIENT_WEBSOCKET}
    FWebSocketEnabled   : Boolean;
    FWebSocketURI       : RawByteString;
    FWebSocketOrigin    : RawByteString;
    FWebSocketProtocol  : RawByteString;
    {$ENDIF}

    FUseWorkerThread    : Boolean;

    FWaitForStartup     : Boolean;

    FTrackLastActivityTime : Boolean;

    FUserTag            : NativeInt;
    FUserObject         : TObject;

    // event handlers
    FOnLog               : TTCPClientLogEvent;

    FOnError             : TTCPClientErrorEvent;
    FOnStateChanged      : TTCPClientStateEvent;
    FOnActive            : TTCPClientNotifyEvent;
    FOnStart             : TTCPClientNotifyEvent;
    FOnStartFailed       : TTCPClientNotifyEvent;
    FOnStarted           : TTCPClientNotifyEvent;
    FOnConnectFailed     : TTCPClientNotifyEvent;
    FOnConnected         : TTCPClientNotifyEvent;
    FOnNegotiating       : TTCPClientNotifyEvent;
    FOnReadyFailed       : TTCPClientNotifyEvent;
    FOnReady             : TTCPClientNotifyEvent;
    FOnRead              : TTCPClientNotifyEvent;
    FOnWrite             : TTCPClientNotifyEvent;
    FOnReadActivity      : TTCPClientNotifyEvent;
    FOnReadShutdown      : TTCPClientNotifyEvent;
    FOnShutdown          : TTCPClientNotifyEvent;
    FOnClose             : TTCPClientNotifyEvent;
    FOnStop              : TTCPClientNotifyEvent;
    FOnStopped           : TTCPClientNotifyEvent;
    FOnInactive          : TTCPClientNotifyEvent;

    FOnProcessThreadIdle : TTCPClientNotifyEvent;
    FOnMainThreadWait    : TTCPClientNotifyEvent;
    FOnThreadWait        : TTCPClientNotifyEvent;
    FOnWorkerExecute     : TTCPClientWorkerExecuteEvent;

    // state
    FLock              : TCriticalSection;
    FActive            : Boolean;
    FState             : TTCPClientState;
    FIsStopping        : Boolean;
    FErrorMessage      : String;
    FErrorCode         : NativeInt;
    FWaitStartEvent    : TAbortableMultiWaitEvent;
    FWaitReadyEvent    : TAbortableMultiWaitEvent;
    FProcessThread     : TTCPClientProcessThread;
    FActivateOnLoaded  : Boolean;
    FIPAddressFamily   : TIPAddressFamily;
    FSocket            : TSysSocket;
    FLocalAddr         : TSocketAddr;
    FConnectAddr       : TSocketAddr;
    FConnection        : TTCPConnection;

    {$IFDEF TCPCLIENT_TLS}
    FTLSProxy          : TTCPConnectionProxy;
    FTLSClient         : TTLSClient;
    {$ENDIF}

    {$IFDEF TCPCLIENT_SOCKS}
    FSocksResolvedAddr : TSocketAddr;
    {$ENDIF}

    {$IFDEF TCPCLIENT_WEBSOCKET}
    FWebSocketProxy    : TTCPConnectionProxy;
    {$ENDIF}

  protected
    procedure Init; virtual;
    procedure InitDefaults; virtual;

    procedure Lock;
    procedure Unlock;

    procedure Log(const LogType: TTCPClientLogType; const Msg: String; const LogLevel: Integer = 0); overload;
    procedure Log(const LogType: TTCPClientLogType; const Msg: String; const Args: array of const; const LogLevel: Integer = 0); overload;

    function  GetState: TTCPClientState;
    function  GetStateStr: String;
    procedure SetState(const AState: TTCPClientState);

    procedure CheckNotActive;
    procedure CheckActive;

    procedure SetAddressFamily(const AAddressFamily: TTCPClientAddressFamily);
    procedure SetHost(const AHost: String);
    procedure SetPort(const APort: String);
    function  GetPortInt: Integer;
    procedure SetPortInt(const APortInt: Integer);
    procedure SetLocalHost(const ALocalHost: String);
    procedure SetLocalPort(const ALocalPort: String);

    procedure SetRetryFailedConnect(const ARetryFailedConnect: Boolean);
    procedure SetRetryFailedConnectDelaySec(const ARetryFailedConnectDelaySec: Integer);
    procedure SetRetryFailedConnectMaxAttempts(const ARetryFailedConnectMaxAttempts: Integer);
    procedure SetReconnectOnDisconnect(const AReconnectOnDisconnect: Boolean);

    {$IFDEF TCPCLIENT_SOCKS}
    procedure SetSocksProxy(const SocksProxy: Boolean);
    procedure SetSocksHost(const SocksHost: RawByteString);
    procedure SetSocksPort(const SocksPort: RawByteString);
    procedure SetSocksAuth(const SocksAuth: Boolean);
    procedure SetSocksUsername(const SocksUsername: RawByteString);
    procedure SetSocksPassword(const SocksPassword: RawByteString);
    {$ENDIF}

    {$IFDEF TCPCLIENT_TLS}
    procedure SetTLSEnabled(const ATLSEnabled: Boolean);
    procedure SetTLSOptions(const ATLSOptions: TTCPClientTLSOptions);
    procedure SetTLSClientOptions(const ATLSClientOptions: TTCPClientTLSClientOptions);
    procedure SetTLSVersionOptions(const ATLSVersionOptions: TTCPClientTLSVersionOptions);
    procedure SetTLSKeyExchangeOptions(const ATLSKeyExchangeOptions: TTCPClientTLSKeyExchangeOptions);
    procedure SetTLSCipherOptions(const ATLSCipherOptions: TTCPClientTLSCipherOptions);
    procedure SetTLSHashOptions(const ATLSHashOptions: TTCPClientTLSHashOptions);
    {$ENDIF}

    {$IFDEF TCPCLIENT_WEBSOCKET}
    procedure SetWebSocketEnabled(const WebSocketEnabled: Boolean);
    procedure SetWebSocketURI(const WebSocketURI: RawByteString);
    procedure SetWebSocketOrigin(const WebSocketOrigin: RawByteString);
    procedure SetWebSocketProtocol(const WebSocketProtocol: RawByteString);
    {$ENDIF}

    procedure SetUseWorkerThread(const AUseWorkerThread: Boolean);

    procedure SetWaitForStartup(const AWaitForStartup: Boolean);

    procedure Loaded; override;

    procedure LogTriggerException(const ATriggerName: String; const AException: Exception);

    procedure TriggerProcessThreadIdle; virtual;

    procedure TriggerError; virtual;
    procedure TriggerStateChanged; virtual;
    procedure TriggerActive; virtual;
    procedure TriggerStart; virtual;
    procedure TriggerStartFailed; virtual;
    procedure TriggerStarted; virtual;
    procedure TriggerConnected; virtual;
    procedure TriggerConnectFailed; virtual;
    procedure TriggerNegotiating; virtual;
    procedure TriggerReadyFailed; virtual;
    procedure TriggerReady; virtual;
    procedure TriggerRead; virtual;
    procedure TriggerWrite; virtual;
    procedure TriggerReadActivity; virtual;
    procedure TriggerReadShutdown; virtual;
    procedure TriggerShutdown; virtual;
    procedure TriggerClose; virtual;
    procedure TriggerStop; virtual;
    procedure TriggerStopped; virtual;
    procedure TriggerInactive; virtual;

    procedure SetError(const AErrorMsg: String; const AErrorCode: Integer);
    procedure SetStartFailed;
    procedure SetStarted;
    procedure SetConnected;
    procedure SetNegotiating;
    procedure SetReadyFailed;
    procedure SetReady;
    procedure SetClosed;
    procedure SetStopped;

    procedure SocketLog(Sender: TSysSocket; LogType: TSysSocketLogType; Msg: String);

    procedure ConnectionLog(Sender: TTCPConnection; LogType: TTCPLogType; LogMsg: String; LogLevel: Integer);

    procedure ConnectionStateChange(Sender: TTCPConnection; AState: TTCPConnectionState);
    procedure ConnectionReadShutdown(Sender: TTCPConnection);
    procedure ConnectionShutdown(Sender: TTCPConnection);
    procedure ConnectionClose(Sender: TTCPConnection);

    procedure ConnectionRead(Sender: TTCPConnection);
    procedure ConnectionWrite(Sender: TTCPConnection);
    procedure ConnectionReadActivity(Sender: TTCPConnection);

    procedure ConnectionWorkerExecute(Sender: TTCPConnection;
              AConnection: TTCPBlockingConnection; var ACloseOnExit: Boolean);

    {$IFDEF TCPCLIENT_TLS}
    procedure InstallTLSProxy;
    function  GetTLSClient: TTLSClient;
    {$ENDIF}

    {$IFDEF TCPCLIENT_SOCKS}
    procedure InstallSocksProxy;
    {$ENDIF}

    {$IFDEF TCPCLIENT_WEBSOCKET}
    procedure InstallWebSocketProxy;
    {$ENDIF}

    function  GetConnection: TTCPConnection;
    procedure CreateConnection;
    procedure FreeConnection;

    function  GetBlockingConnection: TTCPBlockingConnection;

    procedure DoResolveLocal;
    procedure DoBind;
    procedure DoResolve;
    procedure DoConnect;
    procedure DoClose;

    procedure StartProcessThread;
    procedure StopProcessThread;
    {$IFDEF OS_MSWIN}
    function  ProcessMessage(var MsgTerminated: Boolean): Boolean;
    {$ENDIF}
    procedure ProcessThreadExecute(const AThread: TTCPClientProcessThread);

    procedure TerminateProcessThread;
    procedure TerminateWorkerThread;

    procedure ClientStop;

    procedure ClientDeactivate;
    procedure ClientSetInactive;

    procedure ValidateParameters;

    procedure ClientStart;

    procedure ClientInitialiseActive;
    procedure ClientActivate;
    procedure ClientSetActive;

    procedure SetActive(const AActive: Boolean);

    procedure ClientWaitStartup(const ATimeout: Int32); ////
    // procedure ClientWaitReady(const ATimeout: Int32); ////
    // procedure ClientWaitClose(const ATimeout: Int32); ////

    procedure Wait; virtual;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Finalise;

    // Parameters
    property  AddressFamily: TTCPClientAddressFamily read FAddressFamily write SetAddressFamily default cafIP4;
    property  Host: String read FHost write SetHost;
    property  Port: String read FPort write SetPort;
    property  PortInt: Integer read GetPortInt write SetPortInt;
    property  LocalHost: String read FLocalHost write SetLocalHost;
    property  LocalPort: String read FLocalPort write SetLocalPort;

    property  TrackLastActivityTime: Boolean read FTrackLastActivityTime write FTrackLastActivityTime default True;

    // Connect retry
    // If RetryFailedConnect if True, a failed connection attempt will be
    // retried RetryFailedConnectMaxAttempts times after waiting
    // RetryFailedConnectDelaySec seconds between retries.
    // If RetryFailedConnectMaxAttempts is -1, the connection will be retried
    // until the client is stopped.
    // If ReconnectOnDisconnect is True, a connect will automatically be
    // initiated after an established connection is disconnected.
    property  RetryFailedConnect: Boolean read FRetryFailedConnect write SetRetryFailedConnect default False;
    property  RetryFailedConnectDelaySec: Integer read FRetryFailedConnectDelaySec write SetRetryFailedConnectDelaySec default 60;
    property  RetryFailedConnectMaxAttempts: Integer read FRetryFailedConnectMaxAttempts write SetRetryFailedConnectMaxAttempts default -1;
    property  ReconnectOnDisconnect: Boolean read FReconnectOnDisconnect write SetReconnectOnDisconnect default False;

    // Socks
    {$IFDEF TCPCLIENT_SOCKS}
    property  SocksEnabled: Boolean read FSocksEnabled write SetSocksProxy default False;
    property  SocksHost: RawByteString read FSocksHost write SetSocksHost;
    property  SocksPort: RawByteString read FSocksPort write SetSocksPort;
    property  SocksAuth: Boolean read FSocksAuth write SetSocksAuth default False;
    property  SocksUsername: RawByteString read FSocksUsername write SetSocksUsername;
    property  SocksPassword: RawByteString read FSocksPassword write SetSocksPassword;
    {$ENDIF}

    // TLS
    {$IFDEF TCPCLIENT_TLS}
    property  TLSEnabled: Boolean read FTLSEnabled write SetTLSEnabled default False;
    property  TLSOptions: TTCPClientTLSOptions read FTLSOptions write SetTLSOptions default DefaultTCPClientTLSOptions;
    property  TLSClientOptions: TTCPClientTLSClientOptions read FTLSClientOptions write SetTLSClientOptions default DefaultTLSClientOptions;
    property  TLSVersionOptions: TTCPClientTLSVersionOptions read FTLSVersionOptions write SetTLSVersionOptions default DefaultTLSClientVersionOptions;
    property  TLSKeyExchangeOptions: TTCPClientTLSKeyExchangeOptions read FTLSKeyExchangeOptions write SetTLSKeyExchangeOptions default DefaultTLSClientKeyExchangeOptions;
    property  TLSCipherOptions: TTCPClientTLSCipherOptions read FTLSCipherOptions write SetTLSCipherOptions default DefaultTLSClientCipherOptions;
    property  TLSHashOptions: TTCPClientTLSHashOptions read FTLSHashOptions write SetTLSHashOptions default DefaultTLSClientHashOptions;
    {$ENDIF}

    // WebSocket
    {$IFDEF TCPCLIENT_WEBSOCKET}
    property  WebSocketEnabled: Boolean read FWebSocketEnabled write SetWebSocketEnabled default False;
    property  WebSocketURI: RawByteString read FWebSocketURI write SetWebSocketURI;
    property  WebSocketOrigin: RawByteString read FWebSocketOrigin write SetWebSocketOrigin;
    property  WebSocketProtocol: RawByteString read FWebSocketProtocol write SetWebSocketProtocol;
    {$ENDIF}

    property  OnLog: TTCPClientLogEvent read FOnLog write FOnLog;

    property  OnProcessThreadIdle: TTCPClientNotifyEvent read FOnProcessThreadIdle write FOnProcessThreadIdle;
    property  OnError: TTCPClientErrorEvent read FOnError write FOnError;
    property  OnStateChanged: TTCPClientStateEvent read FOnStateChanged write FOnStateChanged;
    property  OnActive: TTCPClientNotifyEvent read FOnActive write FOnActive;
    property  OnStart: TTCPClientNotifyEvent read FOnStart write FOnStart;
    property  OnStartFailed: TTCPClientNotifyEvent read FOnStartFailed write FOnStartFailed;
    property  OnStarted: TTCPClientNotifyEvent read FOnStarted write FOnStarted;
    property  OnConnected: TTCPClientNotifyEvent read FOnConnected write FOnConnected;
    property  OnConnectFailed: TTCPClientNotifyEvent read FOnConnectFailed write FOnConnectFailed;
    property  OnNegotiating: TTCPClientNotifyEvent read FOnNegotiating write FOnNegotiating;
    property  OnReadyFailed: TTCPClientNotifyEvent read FOnReadyFailed write FOnReadyFailed;
    property  OnReady: TTCPClientNotifyEvent read FOnReady write FOnReady;
    property  OnRead: TTCPClientNotifyEvent read FOnRead write FOnRead;
    property  OnWrite: TTCPClientNotifyEvent read FOnWrite write FOnWrite;
    property  OnReadActivity: TTCPClientNotifyEvent read FOnReadActivity write FOnReadActivity;
    property  OnReadShutdown: TTCPClientNotifyEvent read FOnReadShutdown write FOnReadShutdown;
    property  OnShutdown: TTCPClientNotifyEvent read FOnShutdown write FOnShutdown;
    property  OnClose: TTCPClientNotifyEvent read FOnClose write FOnClose;
    property  OnStop: TTCPClientNotifyEvent read FOnStop write FOnStop;
    property  OnStopped: TTCPClientNotifyEvent read FOnStopped write FOnStopped;
    property  OnInactive: TTCPClientNotifyEvent read FOnInactive write FOnInactive;

    // When WaitForStartup is set, the call to Start or Active := True will only return
    // when the thread has started and the Connection property is available.
    // This option is usally only needed in a non-GUI application.
    property  WaitForStartup: Boolean read FWaitForStartup write SetWaitForStartup default False;

    // state
    property  State: TTCPClientState read GetState;
    property  StateStr: String read GetStateStr;

    property  ErrorMessage: String read FErrorMessage;
    property  ErrorCode: NativeInt read FErrorCode;

    function  IsConnecting: Boolean;
    function  IsConnectingOrConnected: Boolean;
    function  IsConnected: Boolean;
    function  IsConnectionClosed: Boolean;
    function  IsShutdownComplete: Boolean;
    function  IsStopping: Boolean;

    property  Active: Boolean read FActive write SetActive default False;

    procedure Start(const AStartupTimeout: Int32 = DefaultTCPClientStartupTimeout);
    procedure Stop;

    procedure Shutdown;
    procedure Close;

    // TLS
    {$IFDEF TCPCLIENT_TLS}
    property  TLSClient: TTLSClient read GetTLSClient;
    procedure StartTLS;
    {$ENDIF}

    // The Connection property is only available when the client is active,
    // when not active it is nil.
    property  Connection: TTCPConnection read GetConnection;

    // The BlockingConnection can be used in the worker thread for blocking
    // operations.
    // Note: These BlockingConnection should not be used from this object's
    // event handlers.
    property  BlockingConnection: TTCPBlockingConnection read GetBlockingConnection;

    // Worker thread
    // When UseWorkerThread is True, the client will have a worker thread
    // created when it is in the Ready state. OnWorkerExecute will
    // be called where the client can use the blocking connection interface.
    property  UseWorkerThread: Boolean read FUseWorkerThread write SetUseWorkerThread default False;
    property  OnWorkerExecute: TTCPClientWorkerExecuteEvent read FOnWorkerExecute write FOnWorkerExecute;

    // Wait events
    // Called by wait loops in this class (WaitForStartup, WaitForState)
    // When blocking occurs in the main thread, OnMainThreadWait is called.
    // When blocking occurs in another thread, OnThreadWait is called.
    // Usually the handler for OnMainThreadWait calls Application.ProcessMessages.
    property  OnMainThreadWait: TTCPClientNotifyEvent read FOnMainThreadWait write FOnMainThreadWait;
    property  OnThreadWait: TTCPClientNotifyEvent read FOnThreadWait write FOnThreadWait;

    // Blocking helpers
    // These functions will block until a result is available or timeout expires.
    // If TimeOut is set to -1 the function may wait indefinetely for result.
    // Note: These functions should not be called from this object's event handlers.
    function  WaitForState(const AStates: TTCPClientStates; const ATimeOutMs: Integer): TTCPClientState;
    function  WaitForConnect(const ATimeOutMs: Integer): Boolean;
    function  WaitForClose(const ATimeOutMs: Integer): Boolean;

    // User defined values
    property  UserTag: NativeInt read FUserTag write FUserTag;
    property  UserObject: TObject read FUserObject write FUserObject;
  end;



{                                                                              }
{ Component                                                                    }
{                                                                              }
type
  TfclTCPClient = class(TF5TCPClient)
  published
    property  Active;
    property  AddressFamily;
    property  Host;
    property  Port;
    property  LocalHost;
    property  LocalPort;

    property  RetryFailedConnect;
    property  RetryFailedConnectDelaySec;
    property  RetryFailedConnectMaxAttempts;
    property  ReconnectOnDisconnect;

    {$IFDEF TCPCLIENT_SOCKS}
    property  SocksHost;
    property  SocksPort;
    property  SocksAuth;
    property  SocksUsername;
    property  SocksPassword;
    {$ENDIF}

    {$IFDEF TCPCLIENT_TLS}
    property  TLSEnabled;
    property  TLSOptions;
    property  TLSClientOptions;
    property  TLSVersionOptions;
    property  TLSKeyExchangeOptions;
    property  TLSCipherOptions;
    property  TLSHashOptions;
    {$ENDIF}

    {$IFDEF TCPCLIENT_WEBSOCKET}
    property  WebSocketEnabled;
    property  WebSocketURI;
    property  WebSocketOrigin;
    property  WebSocketProtocol;
    {$ENDIF}

    property  WaitForStartup;

    property  OnLog;
    property  OnError;
    property  OnActive;
    property  OnInactive;
    property  OnStart;
    property  OnStop;
    property  OnProcessThreadIdle;
    property  OnStateChanged;
    property  OnStarted;
    property  OnConnected;
    property  OnConnectFailed;
    property  OnNegotiating;
    property  OnReady;
    property  OnRead;
    property  OnWrite;
    property  OnReadShutdown;
    property  OnShutdown;
    property  OnClose;
    property  OnStopped;

    property  UseWorkerThread;
    property  OnWorkerExecute;

    property  OnThreadWait;
    property  OnMainThreadWait;

    property  UserTag;
    property  UserObject;
  end;



implementation



{                                                                              }
{ Error and debug strings                                                      }
{                                                                              }
const
  SError_NotAllowedWhileActive   = 'Operation not allowed while active';
  SError_NotAllowedWhileInactive = 'Operation not allowed while inactive';
  SError_TLSNotActive            = 'TLS not active';
  SError_ProxyNotReady           = 'Proxy not ready';
  SError_InvalidParameter        = 'Invalid parameter';
  SError_StartupFailed           = 'Startup failed';
  SError_HostNotSpecified        = 'Host not specified';
  SError_PortNotSpecified        = 'Port not specified';
  SError_Terminated              = 'Terminated';
  SError_TimedOut                = 'Timed out';

  SClientState : array[TTCPClientState] of String = (
      'Initialise',
      'Starting',
      'Start failed',
      'Started',
      'Connect retry',
      'Resolving local',
      'Resolved local',
      'Bound',
      'Resolving',
      'Resolved',
      'Connecting',
      'Connected',
      'Negotiating proxy',
      'Ready failed',
      'Ready',
      'Closed',
      'Stopped');



{                                                                              }
{ TCP Client State                                                             }
{                                                                              }
const
  TCPClientStates_All = [
      csInit,
      csStarting,
      csStarted,
      csConnectRetry,
      csResolvingLocal,
      csResolvedLocal,
      csBound,
      csResolving,
      csResolved,
      csConnecting,
      csConnected,
      csNegotiating,
      csReady,
      csClosed,
      csStopped
  ];

  TCPClientStates_Connecting = [
      csStarting,
      csStarted,
      csConnectRetry,
      csResolvingLocal,
      csResolvedLocal,
      csBound,
      csResolving,
      csResolved,
      csConnecting,
      csConnected,
      csNegotiating
  ];

  TCPClientStates_ConnectingOrConnected =
      TCPClientStates_Connecting + [
      csReady
  ];

  TCPClientStates_Connected = [
      csReady
  ];

  TCPClientStates_Closed = [
      csInit,
      csStartFailed,
      csReadyFailed,
      csClosed,
      csStopped
  ];



{                                                                              }
{ TCP Client Socks Connection Proxy                                            }
{                                                                              }
{$IFDEF TCPCLIENT_SOCKS}
type
  TTCPClientSocksConnectionProxy = class(TTCPConnectionProxy)
  private
    FTCPClient   : TF5TCPClient;
    FSocksClient : TSocksClient;

    procedure SocksClientClientWrite(const Client: TSocksClient; const Buf; const BufSize: Integer);

  public
    class function ProxyName: String; override;
    
    constructor Create(const TCPClient: TF5TCPClient);
    destructor Destroy; override;

    procedure ProxyStart; override;
    procedure ProcessReadData(const Buf; const BufSize: Integer); override;
    procedure ProcessWriteData(const Buf; const BufSize: Integer); override;
  end;

class function TTCPClientSocksConnectionProxy.ProxyName: String;
begin
  Result := 'Socks';
end;

constructor TTCPClientSocksConnectionProxy.Create(const TCPClient: TF5TCPClient);
begin
  Assert(Assigned(TCPClient));
  inherited Create(TCPClient.Connection);
  FTCPClient := TCPClient;
  FSocksClient := TSocksClient.Create;
  FSocksClient.OnClientWrite := SocksClientClientWrite;
end;

destructor TTCPClientSocksConnectionProxy.Destroy;
begin
  FreeAndNil(FSocksClient);
  inherited Destroy;
end;

procedure TTCPClientSocksConnectionProxy.ProxyStart;
begin
  SetState(prsNegotiating);
  // initialise socks client parameters
  FSocksClient.SocksVersion := scvSocks5;
  case FTCPClient.FSocksResolvedAddr.AddrFamily of
    iaIP4 :
      begin
        FSocksClient.AddrType := scaIP4;
        FSocksClient.AddrIP4  := FTCPClient.FSocksResolvedAddr.AddrIP4;
      end;
    iaIP6 :
      begin
        FSocksClient.AddrType := scaIP6;
        FSocksClient.AddrIP6  := FTCPClient.FSocksResolvedAddr.AddrIP6;
      end;
  else
    raise ETCPClient.Create(SError_InvalidParameter);
  end;
  FSocksClient.AddrPort := FTCPClient.FSocksResolvedAddr.Port;
  if FTCPClient.SocksAuth then
    begin
      FSocksClient.AuthMethod := scamSocks5UserPass;
      FSocksClient.UserID     := FTCPClient.FSocksUsername;
      FSocksClient.Password   := FTCPClient.FSocksPassword;
    end
  else
    FSocksClient.AuthMethod := scamNone;
  // connect
  FSocksClient.Connect;
end;

procedure TTCPClientSocksConnectionProxy.SocksClientClientWrite(const Client: TSocksClient; const Buf; const BufSize: Integer);
begin
  ConnectionPutWriteData(Buf, BufSize);
end;

procedure TTCPClientSocksConnectionProxy.ProcessReadData(const Buf; const BufSize: Integer);
begin
  // check if negotiation completed previously
  case FSocksClient.ReqState of
    scrsSuccess : ConnectionPutReadData(Buf, BufSize); // pass data to connection
    scrsFailed  : ;
  else
    // pass data to socks client
    FSocksClient.ClientData(Buf, BufSize);
    // check completion
    case FSocksClient.ReqState of
      scrsSuccess : SetState(prsFinished);
      scrsFailed  : SetState(prsError);
    end;
  end;
end;

procedure TTCPClientSocksConnectionProxy.ProcessWriteData(const Buf; const BufSize: Integer);
begin
  if FSocksClient.ReqState <> scrsSuccess then
    raise ETCPClient.Create(SError_ProxyNotReady);
  ConnectionPutWriteData(Buf, BufSize);
end;
{$ENDIF}



{                                                                              }
{ TCP Client TLS Connection Proxy                                              }
{                                                                              }
{$IFDEF TCPCLIENT_TLS}
type
  TTCPClientTLSConnectionProxy = class(TTCPConnectionProxy)
  private
    FTCPClient : TF5TCPClient;
    FTLSClient : TTLSClient;

    procedure TLSClientTransportLayerSendProc(const Sender: TTLSConnection; const Buffer; const Size: Integer);
    procedure TLSClientLog(Sender: TTLSConnection; LogType: TTLSLogType; LogMsg: String; LogLevel: Integer);
    procedure TLSClientStateChange(Sender: TTLSConnection; State: TTLSConnectionState);

  public
    class function ProxyName: String; override;

    constructor Create(const ATCPClient: TF5TCPClient);
    destructor Destroy; override;

    procedure ProxyStart; override;
    procedure ProcessReadData(const Buf; const BufSize: Integer); override;
    procedure ProcessWriteData(const Buf; const BufSize: Integer); override;
  end;

class function TTCPClientTLSConnectionProxy.ProxyName: String;
begin
  Result := 'TLS';
end;

constructor TTCPClientTLSConnectionProxy.Create(const ATCPClient: TF5TCPClient);
begin
  Assert(Assigned(ATCPClient));

  inherited Create;

  FTCPClient := ATCPClient;

  FTLSClient := TTLSClient.Create(TLSClientTransportLayerSendProc);

  FTLSClient.OnLog         := TLSClientLog;
  FTLSClient.OnStateChange := TLSClientStateChange;
  FTLSClient.ClientOptions := FTCPClient.TLSClientOptions;

  FTLSClient.VersionOptions     := FTCPClient.TLSVersionOptions;
  FTLSClient.KeyExchangeOptions := FTCPClient.TLSKeyExchangeOptions;
  FTLSClient.CipherOptions      := FTCPClient.TLSCipherOptions;
  FTLSClient.HashOptions        := FTCPClient.TLSHashOptions;
end;

destructor TTCPClientTLSConnectionProxy.Destroy;
begin
  FreeAndNil(FTLSClient);
  inherited Destroy;
end;

procedure TTCPClientTLSConnectionProxy.ProxyStart;
begin
  SetState(prsNegotiating);
  FTLSClient.Start;
end;

procedure TTCPClientTLSConnectionProxy.TLSClientTransportLayerSendProc(const Sender: TTLSConnection; const Buffer; const Size: Integer);
begin
  ConnectionPutWriteData(Buffer, Size);
end;

procedure TTCPClientTLSConnectionProxy.TLSClientLog(Sender: TTLSConnection; LogType: TTLSLogType; LogMsg: String; LogLevel: Integer);
begin
  {$IFDEF TCP_DEBUG_TLS}
  Log(tlDebug, 'TLS:%s', [LogMsg], LogLevel + 1);
  {$ENDIF}
end;

procedure TTCPClientTLSConnectionProxy.TLSClientStateChange(Sender: TTLSConnection; State: TTLSConnectionState);
begin
  case State of
    tlscoApplicationData : SetState(prsFiltering);
    tlscoCancelled,
    tlscoErrorBadProtocol :
      begin
        ConnectionClose;
        FErrorMessage := Sender.ConnectionErrorMessage;
        SetState(prsError);
      end;
    tlscoClosed :
      begin
        ConnectionClose;
        SetState(prsClosed);
      end;
  end;
end;

procedure TTCPClientTLSConnectionProxy.ProcessReadData(const Buf; const BufSize: Integer);
const
  ReadBufSize = TLS_PLAINTEXT_FRAGMENT_MAXSIZE * 2;
var
  ReadBuf : array[0..ReadBufSize - 1] of Byte;
  L : Integer;
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(tlDebug, 'ProcessReadData:%db', [BufSize]);
  {$ENDIF}

  FTLSClient.ProcessTransportLayerReceivedData(Buf, BufSize);
  repeat
    L := FTLSClient.AvailableToRead;
    if L > ReadBufSize then
      L := ReadBufSize;
    if L > 0 then
      begin
        L := FTLSClient.Read(ReadBuf, L);
        if L > 0 then
          ConnectionPutReadData(ReadBuf, L);
      end;
  until L <= 0;
end;

procedure TTCPClientTLSConnectionProxy.ProcessWriteData(const Buf; const BufSize: Integer);
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(tlDebug, 'ProcessWriteData:%db', [BufSize]);
  {$ENDIF}

  FTLSClient.Write(Buf, BufSize);
end;
{$ENDIF}



{                                                                              }
{ TCP Client WebSocket Connection Proxy                                        }
{                                                                              }
{$IFDEF TCPCLIENT_WEBSOCKET}
type
  TTCPClientWebSocketConnectionProxy = class(TTCPConnectionProxy)
  private
    FTCPClient : TF5TCPClient;
    FWebSocketClient : TWebSocketClient;

    procedure WebSocketConnectionTransportLayerSendProc(const Sender: TWebSocketConnection; const Buffer; const Size: Integer);
    procedure WebSocketClientLog(Sender: TWebSocketConnection; LogType: TWebSocketLogType; LogMsg: String; LogLevel: Integer);

  public
    class function ProxyName: String; override;

    constructor Create(const TCPClient: TF5TCPClient);
    destructor Destroy; override;

    procedure ProxyStart; override;
    procedure ProcessReadData(const Buf; const BufSize: Integer); override;
    procedure ProcessWriteData(const Buf; const BufSize: Integer); override;
  end;

class function TTCPClientWebSocketConnectionProxy.ProxyName: String;
begin
  Result := 'WebSocket';
end;

constructor TTCPClientWebSocketConnectionProxy.Create(const TCPClient: TF5TCPClient);
begin
  Assert(Assigned(TCPClient));

  inherited Create(TCPClient.FConnection);
  FTCPClient := TCPClient;
  FWebSocketClient := TWebSocketClient.Create(WebSocketConnectionTransportLayerSendProc);
  FWebSocketClient.OnLog := WebSocketClientLog;
end;

destructor TTCPClientWebSocketConnectionProxy.Destroy;
begin
  FreeAndNil(FWebSocketClient);
  inherited Destroy;
end;

procedure TTCPClientWebSocketConnectionProxy.WebSocketConnectionTransportLayerSendProc(const Sender: TWebSocketConnection; const Buffer; const Size: Integer);
begin
  ConnectionPutWriteData(Buffer, Size);
end;

procedure TTCPClientWebSocketConnectionProxy.WebSocketClientLog(Sender: TWebSocketConnection; LogType: TWebSocketLogType; LogMsg: String; LogLevel: Integer);
begin
  {$IFDEF TCP_DEBUG_WEBSOCKET}
  Log(tlDebug, 'WebSocket:%s', [LogMsg], LogLevel + 1);
  {$ENDIF}
end;

procedure TTCPClientWebSocketConnectionProxy.ProxyStart;
begin
  SetState(prsNegotiating);
  FWebSocketClient.Host := FTCPClient.FHost;
  FWebSocketClient.URI := FTCPClient.FWebSocketURI;
  FWebSocketClient.Origin := FTCPClient.FWebSocketOrigin;
  FWebSocketClient.WebSocketProtocol := FTCPClient.FWebSocketProtocol;
  FWebSocketClient.Start;
end;

procedure TTCPClientWebSocketConnectionProxy.ProcessReadData(const Buf; const BufSize: Integer);
const
  ReadBufSize = 65536;
var
  ReadBuf : array[0..ReadBufSize - 1] of Byte;
  L : Integer;
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(tlDebug, 'ProcessReadData:%db', [BufSize]);
  {$ENDIF}
  FWebSocketClient.ProcessTransportLayerReceivedData(Buf, BufSize);
  repeat
    L := FWebSocketClient.AvailableToRead;
    if L > ReadBufSize then
      L := ReadBufSize;
    if L > 0 then
      begin
        L := FWebSocketClient.Read(ReadBuf, L);
        if L > 0 then
          ConnectionPutReadData(ReadBuf, L);
      end;
  until L <= 0;
end;

procedure TTCPClientWebSocketConnectionProxy.ProcessWriteData(const Buf; const BufSize: Integer);
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(tlDebug, 'ProcessWriteData:%db', [BufSize]);
  {$ENDIF}
  FWebSocketClient.Write(Buf, BufSize);
end;
{$ENDIF}



{                                                                              }
{ TTCPClientProcessThread                                                      }
{                                                                              }
constructor TTCPClientProcessThread.Create(const ATCPClient: TF5TCPClient);
begin
  Assert(Assigned(ATCPClient));
  FTCPClient := ATCPClient;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TTCPClientProcessThread.Execute;
var
  C : TF5TCPClient;
begin
  C := FTCPClient;
  Assert(Assigned(C));
  if Terminated then
    exit;
  C.ProcessThreadExecute(self);
  FTCPClient := nil;
end;



{                                                                              }
{ TTCPClient                                                                   }
{                                                                              }
constructor TF5TCPClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Init;
end;

procedure TF5TCPClient.Init;
begin
  FState := csInit;
  FActivateOnLoaded := False;
  FLock := TCriticalSection.Create;
  FWaitStartEvent := TAbortableMultiWaitEvent.Create;
  FWaitReadyEvent := TAbortableMultiWaitEvent.Create;

  InitDefaults;
end;

procedure TF5TCPClient.InitDefaults;
begin
  FActive := False;
  FAddressFamily := cafIP4;
  FRetryFailedConnect := False;
  FRetryFailedConnectDelaySec := 60;
  FRetryFailedConnectMaxAttempts := -1;
  FReconnectOnDisconnect := False;

  {$IFDEF TCPCLIENT_SOCKS}
  FSocksEnabled := False;
  FSocksAuth    := False;
  {$ENDIF}

  {$IFDEF TCPCLIENT_TLS}
  FTLSEnabled            := False;
  FTLSOptions            := DefaultTCPClientTLSOptions;
  FTLSClientOptions      := DefaultTLSClientOptions;
  FTLSVersionOptions     := DefaultTLSClientVersionOptions;
  FTLSKeyExchangeOptions := DefaultTLSClientKeyExchangeOptions;
  FTLSCipherOptions      := DefaultTLSClientCipherOptions;
  FTLSHashOptions        := DefaultTLSClientHashOptions;
  {$ENDIF}

  {$IFDEF TCPCLIENT_WEBSOCKET}
  FWebSocketEnabled := False;
  FWebSocketURI     := '/';
  {$ENDIF}

  FWaitForStartup := False;
  FTrackLastActivityTime := True;
  FUseWorkerThread := False;
end;

destructor TF5TCPClient.Destroy;
begin
  if Assigned(FProcessThread) then
    try
      if not FProcessThread.Terminated then
        FProcessThread.Terminate;
      FProcessThread.WaitFor;
    except
    end;
  FreeAndNil(FProcessThread);

  FreeAndNil(FConnection);
  FreeAndNil(FSocket);

  FreeAndNil(FWaitReadyEvent);
  FreeAndNil(FWaitStartEvent);
  FreeAndNil(FLock);

  inherited Destroy;
end;

procedure TF5TCPClient.Finalise;
begin
  if Assigned(FConnection) then
    FConnection.Finalise;
end;



{ Lock }

procedure TF5TCPClient.Lock;
begin
  Assert(Assigned(FLock));
  FLock.Acquire;
end;

procedure TF5TCPClient.Unlock;
begin
  Assert(Assigned(FLock));
  FLock.Release;
end;



{ Log }

procedure TF5TCPClient.Log(const LogType: TTCPClientLogType; const Msg: String; const LogLevel: Integer);
begin
  if Assigned(FOnLog) then
    try
      FOnLog(Self, LogType, Msg, LogLevel);
    except
    end;
end;

procedure TF5TCPClient.Log(const LogType: TTCPClientLogType; const Msg: String;
    const Args: array of const; const LogLevel: Integer);
begin
  Log(LogType, Format(Msg, Args), LogLevel);
end;



{ State }

function TF5TCPClient.GetState: TTCPClientState;
begin
  Lock;
  try
    Result := FState;
  finally
    Unlock;
  end;
end;

function TF5TCPClient.GetStateStr: String;
var
  S : String;
begin
  Lock;
  try
    S := SClientState[FState];
  finally
    Unlock;
  end;
  if FErrorMessage <> '' then
    S := S + ': ' + FErrorMessage;
  Result := S;
end;

procedure TF5TCPClient.SetState(const AState: TTCPClientState);
begin
  Lock;
  try
    Assert(AState <> FState);
    FState := AState;
  finally
    Unlock;
  end;
  TriggerStateChanged;
end;

procedure TF5TCPClient.CheckNotActive;
begin
  if not (csDesigning in ComponentState) then
    if FActive then
      raise ETCPClient.Create(SError_NotAllowedWhileActive);
end;

procedure TF5TCPClient.CheckActive;
begin
  if not FActive then
    raise ETCPClient.Create(SError_NotAllowedWhileInactive);
end;



{ Property setters }

procedure TF5TCPClient.SetAddressFamily(const AAddressFamily: TTCPClientAddressFamily);
begin
  if AAddressFamily = FAddressFamily then
    exit;
  CheckNotActive;
  FAddressFamily := AAddressFamily;
end;

procedure TF5TCPClient.SetHost(const AHost: String);
begin
  if AHost = FHost then
    exit;
  CheckNotActive;
  FHost := AHost;

  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'Host:%s', [AHost]);
  {$ENDIF}
end;

procedure TF5TCPClient.SetPort(const APort: String);
begin
  if APort = FPort then
    exit;
  CheckNotActive;
  FPort := APort;

  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'Port:%s', [APort]);
  {$ENDIF}
end;

function TF5TCPClient.GetPortInt: Integer;
begin
  Result := StrToIntDef(FPort, -1)
end;

procedure TF5TCPClient.SetPortInt(const APortInt: Integer);
begin
  SetPort(IntToStr(APortInt));
end;

procedure TF5TCPClient.SetLocalHost(const ALocalHost: String);
begin
  if ALocalHost = FLocalHost then
    exit;
  CheckNotActive;
  FLocalHost := ALocalHost;

  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'LocalHost:%s', [ALocalHost]);
  {$ENDIF}
end;

procedure TF5TCPClient.SetLocalPort(const ALocalPort: String);
begin
  if ALocalPort = FLocalPort then
    exit;
  CheckNotActive;
  FLocalPort := ALocalPort;
end;

procedure TF5TCPClient.SetRetryFailedConnect(const ARetryFailedConnect: Boolean);
begin
  if ARetryFailedConnect = FRetryFailedConnect then
    exit;
  CheckNotActive;
  FRetryFailedConnect := ARetryFailedConnect;
end;

procedure TF5TCPClient.SetRetryFailedConnectDelaySec(const ARetryFailedConnectDelaySec: Integer);
begin
  if ARetryFailedConnectDelaySec = FRetryFailedConnectDelaySec then
    exit;
  CheckNotActive;
  FRetryFailedConnectDelaySec := ARetryFailedConnectDelaySec;
end;

procedure TF5TCPClient.SetRetryFailedConnectMaxAttempts(const ARetryFailedConnectMaxAttempts: Integer);
begin
  if ARetryFailedConnectMaxAttempts = FRetryFailedConnectMaxAttempts then
    exit;
  CheckNotActive;
  FRetryFailedConnectMaxAttempts := ARetryFailedConnectMaxAttempts;
end;

procedure TF5TCPClient.SetReconnectOnDisconnect(const AReconnectOnDisconnect: Boolean);
begin
  if AReconnectOnDisconnect = FReconnectOnDisconnect then
    exit;
  CheckNotActive;
  FReconnectOnDisconnect := AReconnectOnDisconnect;
end;

{$IFDEF TCPCLIENT_SOCKS}
procedure TF5TCPClient.SetSocksProxy(const SocksProxy: Boolean);
begin
  if SocksProxy = FSocksEnabled then
    exit;
  CheckNotActive;
  FSocksEnabled := SocksProxy;
end;

procedure TF5TCPClient.SetSocksHost(const SocksHost: RawByteString);
begin
  if SocksHost = FSocksHost then
    exit;
  CheckNotActive;
  FSocksHost := SocksHost;
end;

procedure TF5TCPClient.SetSocksPort(const SocksPort: RawByteString);
begin
  if SocksPort = FSocksPort then
    exit;
  CheckNotActive;
  FSocksHost := SocksHost;
end;

procedure TF5TCPClient.SetSocksAuth(const SocksAuth: Boolean);
begin
  if SocksAuth = FSocksAuth then
    exit;
  CheckNotActive;
  FSocksAuth := SocksAuth;
end;

procedure TF5TCPClient.SetSocksUsername(const SocksUsername: RawByteString);
begin
  if SocksUsername = FSocksUsername then
    exit;
  CheckNotActive;
  FSocksUsername := SocksUsername;
end;

procedure TF5TCPClient.SetSocksPassword(const SocksPassword: RawByteString);
begin
  if SocksPassword = FSocksPassword then
    exit;
  CheckNotActive;
  FSocksPassword := SocksPassword;
end;
{$ENDIF}

{$IFDEF TCPCLIENT_TLS}
procedure TF5TCPClient.SetTLSEnabled(const ATLSEnabled: Boolean);
begin
  if ATLSEnabled = FTLSEnabled then
    exit;
  CheckNotActive;
  FTLSEnabled := ATLSEnabled;

  {$IFDEF TCP_DEBUG_TLS}
  Log(cltDebug, 'TLSEnabled:%d', [Ord(ATLSEnabled)]);
  {$ENDIF}
end;

procedure TF5TCPClient.SetTLSOptions(const ATLSOptions: TTCPClientTLSOptions);
begin
  if ATLSOptions = FTLSOptions then
    exit;
  CheckNotActive;
  FTLSOptions := ATLSOptions;
end;

procedure TF5TCPClient.SetTLSClientOptions(const ATLSClientOptions: TTCPClientTLSClientOptions);
begin
  if ATLSClientOptions = FTLSClientOptions then
    exit;
  CheckNotActive;
  FTLSClientOptions := ATLSClientOptions;
end;

procedure TF5TCPClient.SetTLSVersionOptions(const ATLSVersionOptions: TTCPClientTLSVersionOptions);
begin
  if ATLSVersionOptions = FTLSVersionOptions then
    exit;
  CheckNotActive;
  FTLSVersionOptions := ATLSVersionOptions;
end;

procedure TF5TCPClient.SetTLSKeyExchangeOptions(const ATLSKeyExchangeOptions: TTCPClientTLSKeyExchangeOptions);
begin
  if ATLSKeyExchangeOptions = FTLSKeyExchangeOptions then
    exit;
  CheckNotActive;
  FTLSKeyExchangeOptions := ATLSKeyExchangeOptions;
end;

procedure TF5TCPClient.SetTLSCipherOptions(const ATLSCipherOptions: TTCPClientTLSCipherOptions);
begin
  if ATLSCipherOptions = FTLSCipherOptions then
    exit;
  CheckNotActive;
  FTLSCipherOptions := ATLSCipherOptions;
end;

procedure TF5TCPClient.SetTLSHashOptions(const ATLSHashOptions: TTCPClientTLSHashOptions);
begin
  if ATLSHashOptions = FTLSHashOptions then
    exit;
  CheckNotActive;
  FTLSHashOptions := ATLSHashOptions;
end;
{$ENDIF}

{$IFDEF TCPCLIENT_WEBSOCKET}
procedure TF5TCPClient.SetWebSocketEnabled(const WebSocketEnabled: Boolean);
begin
  if WebSocketEnabled = FWebSocketEnabled then
    exit;
  CheckNotActive;
  FWebSocketEnabled := WebSocketEnabled;

  {$IFDEF TCP_DEBUG_WEBSOCKET}
  Log(cltDebug, 'WebSocketEnabled:%d', [Ord(WebSocketEnabled)]);
  {$ENDIF}
end;

procedure TF5TCPClient.SetWebSocketURI(const WebSocketURI: RawByteString);
begin
  if WebSocketURI = FWebSocketURI then
    exit;
  CheckNotActive;
  FWebSocketURI := WebSocketURI;
end;

procedure TF5TCPClient.SetWebSocketOrigin(const WebSocketOrigin: RawByteString);
begin
  if WebSocketOrigin = FWebSocketOrigin then
    exit;
  CheckNotActive;
  FWebSocketOrigin := WebSocketOrigin;
end;

procedure TF5TCPClient.SetWebSocketProtocol(const WebSocketProtocol: RawByteString);
begin
  if WebSocketProtocol = FWebSocketProtocol then
    exit;
  CheckNotActive;
  FWebSocketProtocol := WebSocketProtocol;
end;
{$ENDIF}

procedure TF5TCPClient.SetUseWorkerThread(const AUseWorkerThread: Boolean);
begin
  if AUseWorkerThread = FUseWorkerThread then
    exit;
  CheckNotActive;
  FUseWorkerThread := AUseWorkerThread;
end;

procedure TF5TCPClient.SetWaitForStartup(const AWaitForStartup: Boolean);
begin
  if AWaitForStartup = FWaitForStartup then
    exit;
  CheckNotActive;
  FWaitForStartup := AWaitForStartup;
end;

procedure TF5TCPClient.Loaded;
begin
  inherited Loaded;

  if FActivateOnLoaded then
    ClientSetActive;
end;



{ Trigger }

procedure TF5TCPClient.LogTriggerException(const ATriggerName: String; const AException: Exception);
begin
  Log(cltError, 'Trigger%s.Error:Error=%s:%s', [AException.ClassName, AException.Message]);
end;

procedure TF5TCPClient.TriggerProcessThreadIdle;
begin
  if Assigned(FOnProcessThreadIdle) then
    FOnProcessThreadIdle(self);
  Sleep(1);
end;

procedure TF5TCPClient.TriggerError;
begin
  Log(cltError, 'Error:%d:%s', [FErrorCode, FErrorMessage]);

  if Assigned(FOnError) then
    try
      FOnError(self, FErrorMessage, FErrorCode);
    except
      on E : Exception do
        LogTriggerException('Error', E);
    end;
end;

procedure TF5TCPClient.TriggerStateChanged;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'State:%s', [GetStateStr]);
  {$ENDIF}

  if Assigned(FOnStateChanged) then
    try
      FOnStateChanged(self, FState);
    except
      on E : Exception do LogTriggerException('StateChanged', E);
    end;
end;

procedure TF5TCPClient.TriggerActive;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Active');
  {$ENDIF}

  if Assigned(FOnActive) then
    try
      FOnActive(self);
    except
      on E : Exception do LogTriggerException('Active', E);
    end;
end;

procedure TF5TCPClient.TriggerStart;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Start');
  {$ENDIF}

  if Assigned(FOnStart) then
    try
      FOnStart(self);
    except
      on E : Exception do LogTriggerException('Start', E);
    end;
end;

procedure TF5TCPClient.TriggerStartFailed;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Start');
  {$ENDIF}

  if Assigned(FOnStartFailed) then
    try
      FOnStartFailed(self);
    except
      on E : Exception do LogTriggerException('StartFailed', E);
    end;
end;

procedure TF5TCPClient.TriggerStarted;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Started');
  {$ENDIF}

  if Assigned(FOnStarted) then
    try
      FOnStarted(self);
    except
      on E : Exception do LogTriggerException('Started', E);
    end;
end;

procedure TF5TCPClient.TriggerConnected;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Connected');
  {$ENDIF}

  if Assigned(FOnConnected) then
    try
      FOnConnected(self);
    except
      on E : Exception do LogTriggerException('Connected', E);
    end;
end;

procedure TF5TCPClient.TriggerNegotiating;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Negotiating');
  {$ENDIF}

  if Assigned(FOnNegotiating) then
    FOnNegotiating(self);
end;

procedure TF5TCPClient.TriggerConnectFailed;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'ConnectFailed');
  {$ENDIF}

  if Assigned(FOnConnectFailed) then
    try
      FOnConnectFailed(self);
    except
      on E : Exception do LogTriggerException('ConnectFailed', E);
    end;
end;

procedure TF5TCPClient.TriggerReadyFailed;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'ReadyFailed');
  {$ENDIF}

  if Assigned(FOnReadyFailed) then
    try
      FOnReadyFailed(self);
    except
      on E : Exception do LogTriggerException('ReadyFailed', E);
    end;
end;

procedure TF5TCPClient.TriggerReady;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Ready');
  {$ENDIF}

  if Assigned(FOnReady) then
    try
      FOnReady(self);
    except
      on E : Exception do LogTriggerException('Ready', E);
    end;
end;

procedure TF5TCPClient.TriggerRead;
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(cltDebug, 'Read');
  {$ENDIF}

  if Assigned(FOnRead) then
    try
      FOnRead(self);
    except
      on E : Exception do LogTriggerException('Read', E);
    end;
end;

procedure TF5TCPClient.TriggerWrite;
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(cltDebug, 'Write');
  {$ENDIF}

  if Assigned(FOnWrite) then
    try
      FOnWrite(self);
    except
      on E : Exception do LogTriggerException('Write', E);
    end;
end;

procedure TF5TCPClient.TriggerReadActivity;
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(cltDebug, 'Activity');
  {$ENDIF}

  if Assigned(FOnReadActivity) then
    try
      FOnReadActivity(self);
    except
      on E : Exception do LogTriggerException('ReadActivity', E);
    end;
end;

procedure TF5TCPClient.TriggerReadShutdown;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'ReadShutdown');
  {$ENDIF}

  if Assigned(FOnReadShutdown) then
    try
      FOnReadShutdown(self);
    except
      on E : Exception do LogTriggerException('ReadShutdown', E);
    end;
end;

procedure TF5TCPClient.TriggerShutdown;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Shutdown');
  {$ENDIF}

  if Assigned(FOnShutdown) then
    try
      FOnShutdown(self);
    except
      on E : Exception do LogTriggerException('Shutdown', E);
    end;
end;

procedure TF5TCPClient.TriggerClose;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Close');
  {$ENDIF}

  if Assigned(FOnClose) then
    try
      FOnClose(self);
    except
      on E : Exception do LogTriggerException('Close', E);
    end;
end;

procedure TF5TCPClient.TriggerStop;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Stop');
  {$ENDIF}

  if Assigned(FOnStop) then
    try
      FOnStop(self);
    except
      on E : Exception do LogTriggerException('Stop', E);
    end;
end;

procedure TF5TCPClient.TriggerStopped;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Stopped');
  {$ENDIF}

  if Assigned(FOnStopped) then
    try
      FOnStopped(self);
    except
      on E : Exception do LogTriggerException('Stopped', E);
    end;
end;

procedure TF5TCPClient.TriggerInactive;
begin
  {$IFDEF TCP_LOG_DEBUG}
  Log(cltDebug, 'Inactive');
  {$ENDIF}

  if Assigned(FOnInactive) then
    try
      FOnInactive(self);
    except
      on E : Exception do LogTriggerException('Inactive', E);
    end;
end;



{ SetStates }

procedure TF5TCPClient.SetError(const AErrorMsg: String; const AErrorCode: Integer);
begin
  {.IFDEF TCP_DEBUG}
  Log(cltError, 'Error:%d:%s', [AErrorCode, AErrorMsg]);
  {.ENDIF}

  FErrorMessage := AErrorMsg;
  FErrorCode := AErrorCode;
  TriggerError;
end;

procedure TF5TCPClient.SetStartFailed;
begin
  SetState(csStartFailed);
  TriggerStartFailed;
end;

procedure TF5TCPClient.SetStarted;
begin
  SetState(csStarted);
  TriggerStarted;
end;

procedure TF5TCPClient.SetConnected;
begin
  SetState(csConnected);
  TriggerConnected;
  FConnection.Start;
end;

procedure TF5TCPClient.SetNegotiating;
begin
  SetState(csNegotiating);
  TriggerNegotiating;
end;

procedure TF5TCPClient.SetReadyFailed;
begin
  SetState(csReadyFailed);
  TriggerReadyFailed;
end;

procedure TF5TCPClient.SetReady;
begin
  SetState(csReady);
  TriggerReady;
  FWaitReadyEvent.SetEvent;
end;

procedure TF5TCPClient.SetClosed;
begin
  Lock;
  try
    if FState in [csInit, csStartFailed, csReadyFailed, csClosed, csStopped] then
      exit;
    FState := csClosed;
  finally
    Unlock;
  end;
  TriggerStateChanged;
  TriggerClose;
end;

procedure TF5TCPClient.SetStopped;
begin
  SetState(csStopped);
  TriggerStopped;
end;

{ Socket }

procedure TF5TCPClient.SocketLog(Sender: TSysSocket; LogType: TSysSocketLogType; Msg: String);
begin
  {$IFDEF TCP_DEBUG_SOCKET}
  Log(cltDebug, 'Socket:%s', [Msg], 10);
  {$ENDIF}
end;

{ Connection events }

procedure TF5TCPClient.ConnectionLog(Sender: TTCPConnection; LogType: TTCPLogType; LogMsg: String; LogLevel: Integer);
begin
  {$IFDEF TCP_DEBUG_CONNECTION}
  Log(cltDebug, 'Connection:%s', [LogMsg], LogLevel + 1);
  {$ELSE}
  if LogType = tlError then
    Log(cltError, 'Connection:%s', [LogMsg], LogLevel + 1);
  {$ENDIF}
end;

procedure TF5TCPClient.ConnectionStateChange(Sender: TTCPConnection; AState: TTCPConnectionState);
begin
  {$IFDEF TCP_DEBUG_CONNECTION}
  Log(cltDebug, 'Connection_StateChange:%s', [Sender.StateStr]);
  {$ENDIF}

  case AState of
    cnsProxyNegotiation : SetNegotiating;
    cnsConnected        : SetReady;
  end;
end;

procedure TF5TCPClient.ConnectionReadShutdown(Sender: TTCPConnection);
begin
  {$IFDEF TCP_DEBUG_CONNECTION}
  Log(cltDebug, 'Connection_ReadShutdown');
  {$ENDIF}

  TriggerReadShutdown;
end;

procedure TF5TCPClient.ConnectionShutdown(Sender: TTCPConnection);
begin
  {$IFDEF TCP_DEBUG_CONNECTION}
  Log(cltDebug, 'Connection_Shutdown');
  {$ENDIF}

  TriggerShutdown;
end;

procedure TF5TCPClient.ConnectionClose(Sender: TTCPConnection);
begin
  {$IFDEF TCP_DEBUG_CONNECTION}
  Log(cltDebug, 'Connection_Close');
  {$ENDIF}

  SetClosed;
end;

procedure TF5TCPClient.ConnectionRead(Sender: TTCPConnection);
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(cltDebug, 'Connection_Read');
  {$ENDIF}

  TriggerRead;
end;

procedure TF5TCPClient.ConnectionWrite(Sender: TTCPConnection);
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(cltDebug, 'Connection_Write');
  {$ENDIF}

  TriggerWrite;
end;

procedure TF5TCPClient.ConnectionReadActivity(Sender: TTCPConnection);
begin
  {$IFDEF TCP_DEBUG_DATA}
  Log(cltDebug, 'Connection_ReadActivity');
  {$ENDIF}

  TriggerReadActivity;
end;

procedure TF5TCPClient.ConnectionWorkerExecute(
          Sender: TTCPConnection;
          AConnection: TTCPBlockingConnection;
          var ACloseOnExit: Boolean);
begin
  if Assigned(FOnWorkerExecute) then
    FOnWorkerExecute(self, AConnection, ACloseOnExit);
end;

{ Proxies }

{$IFDEF TCPCLIENT_TLS}
procedure TF5TCPClient.InstallTLSProxy;
var
  Proxy : TTCPClientTLSConnectionProxy;
begin
  {$IFDEF TCP_DEBUG_TLS}
  Log(cltDebug, 'InstallTLSProxy');
  {$ENDIF}

  Proxy := TTCPClientTLSConnectionProxy.Create(self);
  FTLSProxy := Proxy;
  FTLSClient := Proxy.FTLSClient;
  FConnection.AddProxy(Proxy);
end;

function TF5TCPClient.GetTLSClient: TTLSClient;
var C : TTLSClient;
begin
  C := FTLSClient;
  if not Assigned(C) then
    raise ETCPClient.Create(SError_TLSNotActive);
  Result := C;
end;
{$ENDIF}

{$IFDEF TCPCLIENT_SOCKS}
procedure TF5TCPClient.InstallSocksProxy;
begin
  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'InstallSocksProxy');
  {$ENDIF}

  FConnection.AddProxy(TTCPClientSocksConnectionProxy.Create(self));
end;
{$ENDIF}

{$IFDEF TCPCLIENT_WEBSOCKET}
procedure TF5TCPClient.InstallWebSocketProxy;
begin
  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'InstallWebSocketProxy');
  {$ENDIF}

  FConnection.AddProxy(TTCPClientWebSocketConnectionProxy.Create(self));
end;
{$ENDIF}

{ Connection }

function TF5TCPClient.GetConnection: TTCPConnection;
begin
  Result := FConnection;
end;

procedure TF5TCPClient.CreateConnection;
var
  AF : TIPAddressFamily;
begin
  Lock;
  try
    Assert(FActive);
    Assert(FState = csStarting);
    Assert(not Assigned(FSocket));
    Assert(not Assigned(FConnection));

    case FAddressFamily of
      cafIP4 : AF := iaIP4;
      cafIP6 : AF := iaIP6;
    else
      raise ETCPClient.Create('Invalid address family');
    end;
    FIPAddressFamily := AF;

    FSocket := TSysSocket.Create(AF, ipTCP, False, INVALID_SOCKETHANDLE);
    {$IFDEF TCP_DEBUG}
    FSocket.OnLog := SocketLog;
    {$ENDIF}

    FConnection := TTCPConnection.Create(FSocket);
    FConnection.OnLog           := ConnectionLog;
    FConnection.OnStateChange   := ConnectionStateChange;
    FConnection.OnReadShutdown  := ConnectionReadShutdown;
    FConnection.OnShutdown      := ConnectionShutdown;
    FConnection.OnClose         := ConnectionClose;
    FConnection.OnWorkerExecute := ConnectionWorkerExecute;

    if Assigned(FOnRead) then
      FConnection.OnRead := ConnectionRead;
    if Assigned(FOnWrite) then
      FConnection.OnWrite := ConnectionWrite;
    if Assigned(FOnReadActivity) then
      FConnection.OnReadActivity := ConnectionReadActivity;

    FConnection.UseWorkerThread       := FUseWorkerThread;
    FConnection.TrackLastActivityTime := FTrackLastActivityTime;
  finally
    Unlock;
  end;
end;

procedure TF5TCPClient.FreeConnection;
begin
  if Assigned(FConnection) then
    begin
      FConnection.Finalise;
      FreeAndNil(FConnection);
    end;
  FreeAndNil(FSocket);
end;

function TF5TCPClient.GetBlockingConnection: TTCPBlockingConnection;
begin
  Lock;
  try
    if Assigned(FConnection) then
      Result := FConnection.BlockingConnection
    else
      Result := nil;
  finally
    Unlock;
  end;
end;

{ Resolve }

procedure TF5TCPClient.DoResolveLocal;
var
  LocAddr : TSocketAddr;
begin
  Assert(FActive);
  Assert(FState in [csStarted, csConnectRetry, csClosed]);
  Assert(FHost <> '');
  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'DoResolveLocal');
  {$ENDIF}

  SetState(csResolvingLocal);
  LocAddr := flcSocketLib.Resolve(FLocalHost, FLocalPort, FIPAddressFamily, ipTCP);
  Lock;
  try
    FLocalAddr := LocAddr;
  finally
    Unlock;
  end;
  SetState(csResolvedLocal);
end;

procedure TF5TCPClient.DoBind;
begin
  Assert(FActive);
  Assert(FState in [csResolvedLocal, csClosed]);
  Assert(Assigned(FSocket));
  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'DoBind');
  {$ENDIF}

  if GetState = csClosed then
    raise ETCPClient.Create('Closed');
  FSocket.Bind(FLocalAddr);
  SetState(csBound);
end;

procedure TF5TCPClient.DoResolve;
var
  ConAddr : TSocketAddr;
begin
  Assert(FActive);
  Assert(FState in [csBound, csConnectRetry, csClosed]);
  Assert(FHost <> '');
  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'DoResolve');
  {$ENDIF}

  if GetState = csClosed then
    raise ETCPClient.Create('Closed');
  SetState(csResolving);
  ConAddr := flcSocketLib.Resolve(FHost, FPort, FIPAddressFamily, ipTCP);

  Lock;
  try
    {$IFDEF TCPCLIENT_SOCKS}
    if FState = csClosed then
      raise ETCPClient.Create('Closed');
    if FSocksEnabled then
      begin
        FSocksResolvedAddr := ConAddr;
        ConAddr := flcSocketLib.ResolveA(FSocksHost, FSocksPort, FIPAddressFamily, ipTCP);
      end
    else
      InitSocketAddrNone(FSocksResolvedAddr);
    {$ENDIF}
    FConnectAddr := ConAddr;
  finally
    Unlock;
  end;
  SetState(csResolved);
end;

{ Connect / Close }

procedure TF5TCPClient.DoConnect;
begin
  Assert(FActive);
  Assert(FState in [csResolved, csClosed, csStopped]);
  Assert(Assigned(FSocket));
  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'DoConnect');
  {$ENDIF}

  if GetState = csClosed then
    raise ETCPClient.Create('Closed');
  SetState(csConnecting);
  FSocket.SetBlocking(True);
  FSocket.Connect(FConnectAddr);
  FSocket.SetBlocking(False);
  SetConnected;
end;

procedure TF5TCPClient.DoClose;
begin
  Assert(Assigned(FSocket));
  Assert(Assigned(FConnection));
  {$IFDEF TCP_DEBUG}
  Log(cltDebug, 'DoClose');
  {$ENDIF}

  FConnection.Close;
  SetClosed;
end;

{ Thread }

procedure TF5TCPClient.StartProcessThread;
begin
  {$IFDEF TCP_DEBUG_THREAD}
  Log(cltDebug, 'StartProcessThread');
  {$ENDIF}

  FProcessThread := TTCPClientProcessThread.Create(self);
end;

procedure TF5TCPClient.StopProcessThread;
begin
  if not Assigned(FProcessThread) then
    exit;
  {$IFDEF TCP_DEBUG_THREAD}
  Log(cltDebug, 'StopProcessThread');
  {$ENDIF}

  FProcessThread.Terminate;
  FProcessThread.WaitFor;
  FreeAndNil(FProcessThread);
end;

{$IFDEF OS_MSWIN}
function TF5TCPClient.ProcessMessage(var MsgTerminated: Boolean): Boolean;
var Msg : TMsg;
begin
  Result := PeekMessage(Msg, 0, 0, 0, PM_REMOVE);
  if not Result then
    exit;
  if Msg.Message = WM_QUIT then
    begin
      MsgTerminated := True;
      exit;
    end;
  TranslateMessage(Msg);
  DispatchMessage(Msg);
end;
{$ENDIF}

// The client thread is responsible for connecting and processing the socket.
// Events are dispatches from this thread.
procedure TF5TCPClient.ProcessThreadExecute(const AThread: TTCPClientProcessThread);

  function IsTerminated: Boolean;
  begin
    Result := AThread.Terminated;
    if Result then
      exit;
    Result := IsStopping;
  end;

  procedure SetErrorFromException(const E: Exception);
  begin
    if E is ESocketLib then
      SetError(E.Message, ESocketLib(E).ErrorCode)
    else
      SetError(E.Message, -1);
  end;

  function WaitSec(const NSec: Integer): Boolean;
  var
    T : Word32;
    MS : Word32;
  begin
    Result := True;
    if NSec <= 0 then
      exit;
    MS := Word32(NSec) * 1000;
    T := 0;
    repeat
      if IsTerminated then
        begin
          Result := False;
          exit;
        end;
      Sleep(50);
      Inc(T, 50);
    until T >= MS;
  end;

var
  IsIdle, ConIdle, ConTerminated : Boolean;
  {$IFDEF OS_MSWIN}
  MsgProcessed, MsgTerminated : Boolean;
  {$ENDIF}
  ConnRetry : Boolean;
  ConnAttempt : Integer;
  Reconnect : Boolean;
  RS, WS, ES : Boolean;
  {$IFDEF OS_WIN32}
  SelCnt : Integer;
  {$ENDIF}

begin
  try
    Assert(Assigned(AThread));
    {$IFDEF TCP_DEBUG_THREAD}
    Log(cltDebug, 'ThreadExecute');
    {$ENDIF}

    // startup
    try
      try
        if IsTerminated then
          exit;
        // connection setup
        CreateConnection;
        if IsTerminated then
          exit;
        SetStarted;
        {$IFDEF TCPCLIENT_SOCKS}
        if FSocksEnabled then
          InstallSocksProxy;
        {$ENDIF}
        {$IFDEF TCPCLIENT_TLS}
        if FTLSEnabled then
          InstallTLSProxy;
        {$ENDIF}
        {$IFDEF TCPCLIENT_WEBSOCKET}
        if FWebSocketEnabled then
          InstallWebSocketProxy;
        {$ENDIF}
      except
        on E : Exception do
          begin
            if not IsTerminated then
              begin
                SetErrorFromException(E);
                SetStartFailed;
                TriggerConnectFailed;
                TriggerReadyFailed;
              end;
            exit;
          end;
      end;
    finally
      FWaitStartEvent.SetEvent;
    end;

    Reconnect := False;
    repeat
      try
        if Reconnect then
          begin
            // re-allocate socket handle
            DoClose;
            FSocket.AllocateSocketHandle;
          end;
        FSocket.SetBlocking(True);
        if IsTerminated then
          exit;
        // resolve local
        DoResolveLocal;
        if IsTerminated then
          exit;
        // bind
        DoBind;
        if IsTerminated then
          exit;
      except
        on E : Exception do
          begin
            if not IsTerminated then
              begin
                SetErrorFromException(E);
                TriggerConnectFailed;
                SetReadyFailed;
              end;
            {$IFDEF TCP_DEBUG_THREAD}
            Log(cltDebug, 'ThreadExit:Local bind failed:%s', [E.Message]);
            {$ENDIF}
            exit;
          end;
      end;
      // resolve and connect
      ConnAttempt := 1;
      repeat
        ConnRetry := False;
        try
          // resolve
          if IsTerminated then
            exit;
          DoResolve;
          if IsTerminated then
            exit;
          // connect
          DoConnect;
          if IsTerminated then
            exit;
          // success
        except
          on E : Exception do
            begin
              // retry
              if not IsTerminated and FRetryFailedConnect then
                if (FRetryFailedConnectMaxAttempts < 0) or
                   (ConnAttempt < FRetryFailedConnectMaxAttempts) then
                  begin
                    if not WaitSec(FRetryFailedConnectDelaySec) then
                      exit;
                    Inc(ConnAttempt);
                    ConnRetry := True;
                    SetState(csConnectRetry);
                    if IsTerminated then
                      exit;
                  end;
              if not ConnRetry then
                begin
                  if not IsTerminated then
                    begin
                      SetErrorFromException(E);
                      TriggerConnectFailed;
                      SetReadyFailed;
                    end;
                  {$IFDEF TCP_DEBUG_THREAD}
                  Log(cltDebug, 'ThreadExit:Connection failed:%s', [E.Message]);
                  {$ENDIF}
                  exit;
                end;
              {$IFDEF TCP_DEBUG}
              if ConnRetry then
                Log(cltDebug, 'ConnRetry');
              {$ENDIF}
            end;
        end;
      until not ConnRetry;
      // set socket option
      try
        FSocket.TcpNoDelayEnabled := True;
      except
      end;
      // poll loop
      try
        {$IFDEF OS_MSWIN}
        MsgTerminated := False;
        {$ENDIF}
        while not IsTerminated do
          begin
            // wait for socket activity
            try
              FConnection.ProcessPendingEvents;
              {$IFDEF OS_WIN32}
              // under Win32, WinSock blocks Socket.Write() if Socket.Select() is active
              for SelCnt := 1 to 10 do
                begin
                  RS := True;
                  WS := True;
                  ES := False;
                  FConnection.GetEventsToPoll(RS, WS);
                  FConnection.Socket.Select(50000, RS, WS, ES); // 50,000 microseconds / 50 milliseconds
                  if RS or WS or ES or IsTerminated then
                    break;
                end;
              {$ELSE}
              RS := True;
              WS := True;
              ES := False;
              FConnection.GetEventsToPoll(RS, WS);
              FConnection.Socket.Select(100000, RS, WS, ES); // 100,000 microseconds / 100 milliseconds
              {$ENDIF}
              IsIdle := False;
            except
              IsIdle := True;
            end;
            if IsTerminated then
              break;

            FConnection.ProcessSocket(RS, WS, Now, ConIdle, ConTerminated);
            if ConTerminated then
              begin
                {$IFDEF TCP_DEBUG_THREAD}
                Log(cltDebug, 'ThreadTerminate:ConnectionTerminated');
                {$ENDIF}
                break;
              end
            else
              begin
                if FConnection.ProcessPendingEvents then
                  IsIdle := False
                else
                if not ConIdle then
                  IsIdle := False;
                {$IFDEF OS_MSWIN}
                MsgProcessed := ProcessMessage(MsgTerminated);
                if MsgTerminated then
                  begin
                    AThread.Terminate;
                    {$IFDEF TCP_DEBUG_THREAD}
                    Log(cltDebug, 'ThreadTerminate:MsgTerminated');
                    {$ENDIF}
                  end;
                if MsgProcessed then
                  IsIdle := False;
                {$ENDIF}
                if IsIdle then
                  TriggerProcessThreadIdle;
              end;
          end;
      except
        on E : Exception do
          if not IsTerminated then
            begin
              {$IFDEF TCP_DEBUG_THREAD}
              Log(cltDebug, 'PollLoop:Error:%s', [E.Message]);
              {$ENDIF}
              SetErrorFromException(E);
            end;
      end;
      Reconnect := not IsTerminated and FReconnectOnDisconnect;
    until not Reconnect;
  finally
    if not IsTerminated then
      SetClosed;
  end;

  {$IFDEF TCP_DEBUG_THREAD}
  Log(cltDebug, 'ThreadTerminate:Terminated=%d', [Ord(IsTerminated)]);
  {$ENDIF}
end;

procedure TF5TCPClient.TerminateProcessThread;
begin
  if Assigned(FProcessThread) then
    FProcessThread.Terminate;
end;

procedure TF5TCPClient.TerminateWorkerThread;
begin
  if Assigned(FConnection) then
    FConnection.TerminateWorkerThread;
end;

{ Start / Stop }

procedure TF5TCPClient.ClientStop;
begin
  TriggerStop;
  // terminate threads and close socket before waiting for threads to terminate
  TerminateWorkerThread;
  TerminateProcessThread;
  FWaitStartEvent.SetEvent;
  FWaitReadyEvent.SetEvent;
  DoClose;
  StopProcessThread;
  FConnection.WaitForWorkerThread;
  SetStopped;
end;

procedure TF5TCPClient.ClientDeactivate;
begin
  FActive := False;
  TriggerInactive;
end;

procedure TF5TCPClient.ClientSetInactive;
begin
  Lock;
  try
    if not FActive then
      exit;
    if FIsStopping then
      exit;
    FIsStopping := True;
  finally
    Unlock;
  end;
  try
    ClientStop;
    ClientDeactivate;
    FreeConnection;
  finally
    Lock;
    try
      FIsStopping := False;
    finally
      Unlock;
    end;
  end;
end;

const
  // milliseconds to wait for thread to startup,
  // this usually happens within 1 ms but could pause for a few seconds if the
  // system is busy
  ThreadStartupTimeOut = 30000; // 30 seconds

procedure TF5TCPClient.ValidateParameters;
begin
  if FHost = '' then
    raise ETCPClient.Create(SError_HostNotSpecified);
  if FPort = '' then
    raise ETCPClient.Create(SError_PortNotSpecified);
end;

procedure TF5TCPClient.ClientStart;
begin
  SetState(csStarting);
  TriggerStart;
  StartProcessThread;
end;

procedure TF5TCPClient.ClientInitialiseActive;
begin
  Lock;
  try
    FState := csInit;
    InitSocketAddrNone(FLocalAddr);
    InitSocketAddrNone(FConnectAddr);
    FErrorMessage := '';
    FErrorCode := 0;
    FWaitStartEvent.ResetEvent;
    FWaitReadyEvent.ResetEvent;
  finally
    Unlock;
  end;
end;

procedure TF5TCPClient.ClientActivate;
begin
  ClientInitialiseActive;
  TriggerActive;
  ClientStart;
end;

procedure TF5TCPClient.ClientSetActive;
var
  WaitForStart : Boolean;
begin
  Lock;
  try
    if FActive then
      exit;
    ValidateParameters;
    FActive := True;
    WaitForStart := FWaitForStartup;
  finally
    Unlock;
  end;
  ClientActivate;
  if WaitForStart then
    begin
      FWaitStartEvent.WaitEvent(ThreadStartupTimeOut);
      case GetState of
        csInit,
        csStarting : raise ETCPClient.Create('Startup timeout');
        csStartFailed,
        csReadyFailed,
        csClosed,
        csStopped  : raise ETCPClient.CreateFmt('Started failed: %s', [GetStateStr]);
      end;
    end;
end;

procedure TF5TCPClient.SetActive(const AActive: Boolean);
begin
  if csDesigning in ComponentState then
    FActive := AActive else
  if csLoading in ComponentState then
    FActivateOnLoaded := AActive
  else
    if AActive then
      ClientSetActive
    else
      ClientSetInactive;
end;

////
procedure TF5TCPClient.ClientWaitStartup(const ATimeout: Int32);
var
  T, W : Int32;
begin
  T := ATimeout;
  repeat
    if T < 0 then
      W := 200
    else
      begin
        W := T;
        if W > 200 then
          W := 200;
      end;
    // TAbortableMultiWaitEvent
    case FWaitStartEvent.WaitEvent(W) of
      wrSignaled  : ;
      wrTimeout   : ;
      wrAbandoned : ;
      wrError     : ;
    end;
    if T >= 0 then
      Dec(T, W);
    case GetState of
      csStarted,
      csConnectRetry,
      csResolvingLocal,
      csResolvedLocal,
      csBound,
      csResolving,
      csResolved,
      csConnecting,
      csConnected,
      csNegotiating,
      csReady         : exit;
      csStartFailed,
      csReadyFailed,
      csClosed,
      csStopped       : break;
    end;
  until T = 0;
  case GetState of
    csInit,
    csStarting     : raise ETCPClient.Create('Startup timeout');
    csStartFailed,
    csReadyFailed,
    csClosed,
    csStopped      : raise ETCPClient.CreateFmt('Startup failed: %s', [GetStateStr]);
  end;
end;
////

procedure TF5TCPClient.Start(const AStartupTimeout: Int32);
begin
  ClientSetActive;
end;

procedure TF5TCPClient.Stop;
begin
  ClientSetInactive;
end;

procedure TF5TCPClient.Shutdown;
begin
  Lock;
  try
    if not FActive or FIsStopping then
      exit;
    if FState in [csInit, csStartFailed, csReadyFailed, csClosed, csStopped] then
      exit;
  finally
    Unlock;
  end;
  FConnection.Shutdown;
end;

procedure TF5TCPClient.Close;
begin
  Lock;
  try
    if not FActive or FIsStopping then
      exit;
    if FState in [csInit, csStartFailed, csReadyFailed, csClosed, csStopped] then
      exit;
  finally
    Unlock;
  end;
  DoClose;
end;

{ Connect state }

function TF5TCPClient.IsConnecting: Boolean;
begin
  Result := GetState in TCPClientStates_Connecting;
end;

function TF5TCPClient.IsConnectingOrConnected: Boolean;
begin
  Result := GetState in TCPClientStates_ConnectingOrConnected;
end;

function TF5TCPClient.IsConnected: Boolean;
begin
  Result := GetState in TCPClientStates_Connected;
end;

function TF5TCPClient.IsConnectionClosed: Boolean;
begin
  Result := GetState in TCPClientStates_Closed;
end;

function TF5TCPClient.IsShutdownComplete: Boolean;
begin
  Lock;
  try
    Result :=
        (FState in [csClosed, csStopped]) or
        (FActive and FConnection.IsShutdownComplete);
  finally
    Unlock;
  end;
end;

function TF5TCPClient.IsStopping: Boolean;
begin
  Lock;
  try
    Result := FIsStopping;
  finally
    Unlock;
  end;
end;

{ TLS }

{$IFDEF TCPCLIENT_TLS}
procedure TF5TCPClient.StartTLS;
begin
  CheckActive;
  if FTLSEnabled then // TLS proxy already installed on activation
    exit;
  InstallTLSProxy;
end;
{$ENDIF}

{ Wait }

procedure TF5TCPClient.Wait;
begin
  {$IFDEF OS_MSWIN}
  if GetCurrentThreadID = MainThreadID then
    begin
      if Assigned(OnMainThreadWait) then
        FOnMainThreadWait(self);
    end
  else
    begin
      if Assigned(FOnThreadWait) then
        FOnThreadWait(self);
    end;
  {$ELSE}
  if Assigned(FOnThreadWait) then
    FOnThreadWait(self);
  {$ENDIF}
  Sleep(5);
end;

// Wait until one of the States or time out
function TF5TCPClient.WaitForState(const AStates: TTCPClientStates; const ATimeOutMs: Integer): TTCPClientState;
var T : Word64;
    S : TTCPClientState;
begin
  CheckActive;
  T := TCPGetTick;
  repeat
    S := GetState;
    if S in AStates then
      break;
    if ATimeOutMs >= 0 then
      if TCPTickDelta(T, TCPGetTick) >= ATimeOutMs then
        break;
    Wait;
  until False;
  Result := S;
end;

// Wait until connected (ready), closed or time out
function TF5TCPClient.WaitForConnect(const ATimeOutMs: Integer): Boolean;
begin
  Result := WaitForState([csReady, csStartFailed, csReadyFailed, csReadyFailed, csClosed, csStopped], ATimeOutMs) = csReady;
end;

// Wait until socket is closed or time out
function TF5TCPClient.WaitForClose(const ATimeOutMs: Integer): Boolean;
begin
  Result := WaitForState([csStartFailed, csReadyFailed, csClosed, csStopped], ATimeOutMs) = csClosed;
end;



end.


; #INDEX# =======================================================================================================================
; Title .........: USB
; Version .......: 1.0
; Language ......: Русский
; Description ...: Библиотка для работы с интерфейсом USB.
; Author ........: GreenBytes ( https://vk.com/greenbytes )
; Dll ...........: hid.dll, setupapi.dll
; ===============================================================================================================================

DeclareModule USB
  ;-----------------------------------------------------------
  ;-       USB Constants
  ;{----------------------------------------------------------
  #PID = $8036
  #VID = $2341
  
  #RX = 128 + 1
  #TX = #RX
  ;}----------------------------------------------------------
  ;-       USB Structures
  ;{----------------------------------------------------------
  Structure CAPS
    Usage.w
    UsagePage.w
    InputReportByteLength.w
    OutputReportByteLength.w
    FeatureReportByteLength.w
    Reserved.w[17]
    NumberLinkCollectionNodes.w
    NumberInputButtonCaps.w
    NumberInputValueCaps.w
    NumberInputDataIndices.w
    NumberOutputButtonCaps.w
    NumberOutputValueCaps.w
    NumberOutputDataIndices.w
    NumberFeatureButtonCaps.w
    NumberFeatureValueCaps.w
    NumberFeatureDataIndices.w
  EndStructure
  
  Structure SubDeviceInfo
    VendorID.u
    ProductID.u
    VersionNumber.u
    NumInputBuffers.u
    InputReportByteLength.u
    OutputReportByteLength.u
    FeatureReportByteLength.u
    Manufacturer.s
    Product.s
    SerialNumber.s
  EndStructure
  
  Structure DeviceInfo
    CountDevice.w
    DeviceInfo.SubDeviceInfo[258]
  EndStructure


  Structure Attributes
    VID.u
    PID.u
    VersionNumber.u
  EndStructure
  
  Structure AttributesID
    Size.l
    VendorID.u
    ProductID.u
    VersionNumber.w
  EndStructure
  
  Structure PSP_DEVICE_INTERFACE_DETAIL_DATA
    cbSize.l
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x64
      DevicePath.l
    CompilerElse 
      DevicePath.c
    CompilerEndIf
  EndStructure
  
  CompilerIf Defined(SP_DEVICE_INTERFACE_DATA, #PB_Structure)=0
    Structure SP_DEVICE_INTERFACE_DATA
      cbSize.l
      InterfaceClassGuid.GUID
      Flags.l
      Reserved.l
    EndStructure
  CompilerEndIf
  
  Structure USB
    hDevice.l
    TX.l
    RX.l
    bTX.l
    bRX.l
    wTX.l
    wRX.l
  EndStructure
  
  ;}----------------------------------------------------------
  ;-       USB Declare
  ;{----------------------------------------------------------
  Declare Init()
  Declare Device(Key.l, PID.u = #PID, VID.u = #VID, TX.l = #TX, RX.l = #RX)
  Declare ReadD(*USB.USB)
  Declare WriteD(*USB.USB)
  Declare WriteRead(*USB.USB)
  Declare GetKey(*USB.USB)
  Declare RunB(*USB.USB, Party.b, Detail1.b = $00, Detail2.b = $00, Detail3.b = $00, Detail4.b = $00, Detail5.b = $00)
  Declare.b ReadB(*USB.USB, Offset.l = 0)
  Declare Close(*USB.USB)
  ;}----------------------------------------------------------
  ;-       USB Var
  ;{----------------------------------------------------------
  Global HID_DLL.l, SETUPAPI_DLL.l
  ;}----------------------------------------------------------
EndDeclareModule

Module USB
  ;-----------------------------------------------------------
  ;-       USB -> Prototype
  ;{----------------------------------------------------------
  Prototype HidD_GetHidGuid(*HidGuid.GUID)
  Prototype HidD_GetAttributes(*HidDeviceObject, *Attributes.AttributesID)
  Prototype SetupDiEnumDeviceInterfaces(*DeviceInfoSet, DeviceInfoData, *InterfaceClassGuid.GUID, MemberIndex, *DeviceInterfaceData.SP_DEVICE_INTERFACE_DATA)
  Prototype SetupDiGetDeviceInterfaceDetail(*DeviceInfoSet, *DeviceInterfaceData.SP_DEVICE_INTERFACE_DATA, DeviceInterfaceDetailData, DeviceInterfaceDetailDataSize, *RequiredSize, *DeviceInfoData)
  ;}----------------------------------------------------------
  ;-       USB -> Globals -> Prototype
  ;{----------------------------------------------------------
  Global HidD_GetHidGuid.HidD_GetHidGuid, HidD_GetAttributes.HidD_GetAttributes, SetupDiEnumDeviceInterfaces.SetupDiEnumDeviceInterfaces, SetupDiGetDeviceInterfaceDetail.SetupDiGetDeviceInterfaceDetail
  ;}----------------------------------------------------------
  ;-       Device -> Procedure's
  ;{----------------------------------------------------------
  Procedure.l LoadLibrary(name.s, pLib.i)
    If PeekI(pLib) <> 0
      ProcedureReturn 0
    EndIf
    Define Lib = OpenLibrary(#PB_Any, name)
    If Lib <> 0
      PokeI(pLib, Lib)
      ProcedureReturn 1
    EndIf
    ProcedureReturn 0
  EndProcedure
  
  Procedure IsPrototype()
    If HidD_GetHidGuid = 0 Or HidD_GetAttributes = 0 Or SetupDiEnumDeviceInterfaces = 0 Or SetupDiGetDeviceInterfaceDetail = 0
      ProcedureReturn 0
    EndIf
    ProcedureReturn 1
  EndProcedure
  ;}----------------------------------------------------------
  ;-       USB -> Function
  ;{----------------------------------------------------------
  Procedure Init()
    LoadLibrary("hid.dll", @HID_DLL)
    LoadLibrary("setupapi.dll", @SETUPAPI_DLL)
    
    If HID_DLL
      HidD_GetHidGuid.HidD_GetHidGuid=GetFunction(HID_DLL, "HidD_GetHidGuid") ;
      HidD_GetAttributes.HidD_GetAttributes=GetFunction(HID_DLL, "HidD_GetAttributes") ;
    EndIf
    If SETUPAPI_DLL
      SetupDiEnumDeviceInterfaces.SetupDiEnumDeviceInterfaces=GetFunction(SETUPAPI_DLL, "SetupDiEnumDeviceInterfaces") ;
      SetupDiGetDeviceInterfaceDetail.SetupDiGetDeviceInterfaceDetail=GetFunction(SETUPAPI_DLL, "SetupDiGetDeviceInterfaceDetailW") ;
    EndIf
    ProcedureReturn IsPrototype()
  EndProcedure
  
  Procedure Device(Key.l, PID.u = #PID, VID.u = #VID, TX.l = #TX, RX.l = #RX)
    If Not IsPrototype() : ProcedureReturn 0 : EndIf
    
    Protected Index.l = 0
    
    Protected hDevInfo, devInfoData.SP_DEVICE_INTERFACE_DATA, Security.SECURITY_ATTRIBUTES, HidGuid.Guid, i, Result, Length.l, *detailData.PSP_DEVICE_INTERFACE_DETAIL_DATA, Required
    Protected DevicePath.s, hDevice, Attributes.AttributesID, *USB.USB
    
    devInfoData\cbSize = SizeOf(SP_DEVICE_INTERFACE_DATA)
    
    Security\nLength=SizeOf(SECURITY_ATTRIBUTES)
    Security\bInheritHandle=1
    Security\lpSecurityDescriptor = 0
    
    HidD_GetHidGuid(@HidGuid)
    
    hDevInfo = SetupDiGetClassDevs_(@HidGuid, 0, 0, #DIGCF_PRESENT|#DIGCF_DEVICEINTERFACE)
    If Not hDevInfo : ProcedureReturn 0 : EndIf
    
    For i=0 To 255
      Result = SetupDiEnumDeviceInterfaces(hDevInfo, 0, @HidGuid, i, @devInfoData)
      If Result
        Result = SetupDiGetDeviceInterfaceDetail(hDevInfo, @devInfoData, 0, 0, @Length, 0)
        *detailData = AllocateMemory(Length)
        *detailData\cbSize=SizeOf(PSP_DEVICE_INTERFACE_DETAIL_DATA)
        Result = SetupDiGetDeviceInterfaceDetail(hDevInfo, @devInfoData, *detailData, Length+1, @Required, 0)
        DevicePath.s = PeekS(@*detailData\DevicePath)
        FreeMemory(*detailData)
        hDevice = CreateFile_(@DevicePath, #GENERIC_READ|#GENERIC_WRITE, #FILE_SHARE_READ|#FILE_SHARE_WRITE, @Security, #OPEN_EXISTING, 0, 0)
        If hDevice <> #INVALID_HANDLE_VALUE
          Attributes\Size = SizeOf(AttributesID)
          HidD_GetAttributes(hDevice, @Attributes)
          If Attributes\ProductID = PID And Attributes\VendorID = VID
            *USB = AllocateMemory(SizeOf(USB))
            *USB\hDevice = hDevice
            *USB\RX = RX
            *USB\TX = TX
            *USB\bRX = AllocateMemory(*USB\RX + 1)
            *USB\bTX = AllocateMemory(*USB\TX + 1)
            
            If GetKey(*USB.USB) = Key
              SetupDiDestroyDeviceInfoList_(hDevInfo)
              ProcedureReturn *USB
            EndIf

            FreeMemory(*USB\bRX)
            FreeMemory(*USB\bTX)
            FreeMemory(*USB)
          EndIf
        EndIf
        CloseHandle_(hDevice)
      EndIf
    Next
    SetupDiDestroyDeviceInfoList_(hDevInfo)
    ProcedureReturn 0
  EndProcedure
  
  Procedure Close(*USB.USB)
    If Not *USB : ProcedureReturn 0 : EndIf
    FreeMemory(*USB\bRX)
    FreeMemory(*USB\bTX)
    CloseHandle_(*USB\hDevice)
    FreeMemory(*USB)
    *USB = 0;
    ProcedureReturn 1
  EndProcedure
  
  Procedure ReadD(*USB.USB)
    If Not *USB : ProcedureReturn 0 : EndIf
    If Not IsPrototype() : ProcedureReturn 0 : EndIf
    ProcedureReturn ReadFile_(*USB\hDevice, *USB\bRX, *USB\RX, @*USB\wRX, 0)
  EndProcedure
  
  Procedure WriteD(*USB.USB)
    If Not *USB : ProcedureReturn 0 : EndIf
    If Not IsPrototype() : ProcedureReturn 0 : EndIf
    ProcedureReturn WriteFile_(*USB\hDevice, *USB\bTX, *USB\TX, @*USB\wTX, 0)
  EndProcedure
  
  Procedure WriteRead(*USB.USB)
    If Not *USB : ProcedureReturn 0 : EndIf
    If Not IsPrototype() : ProcedureReturn 0 : EndIf
    If Not WriteD(*USB) : ProcedureReturn 0 : EndIf
    If Not ReadD(*USB) : ProcedureReturn 0 : EndIf
    ProcedureReturn 1
  EndProcedure
  
  Procedure GetKey(*USB.USB)
    If Not *USB : ProcedureReturn 0 : EndIf
    If Not IsPrototype() : ProcedureReturn 0 : EndIf
    PokeB(*USB\bTX + 1, $FF)
    If Not WriteRead(*USB) : ProcedureReturn 0 : EndIf
    ProcedureReturn PeekL(*USB\bRX+2) 
  EndProcedure
  
  Procedure RunB(*USB.USB, Party.b, Detail1.b = $00, Detail2.b = $00, Detail3.b = $00, Detail4.b = $00, Detail5.b = $00)
    If Not *USB : ProcedureReturn 0 : EndIf
    PokeB(*USB\bTX + 1, Party)
    PokeB(*USB\bTX + 2, Detail1)
    PokeB(*USB\bTX + 3, Detail2)
    PokeB(*USB\bTX + 4, Detail3)
    PokeB(*USB\bTX + 5, Detail4)
    PokeB(*USB\bTX + 6, Detail5)
    If Not WriteRead(*USB) : ProcedureReturn 0 : EndIf
    If PeekB(*USB\bRX + 1) = Party : ProcedureReturn 1 : EndIf
  EndProcedure
  
  Procedure.b ReadB(*USB.USB, Offset.l = 0)
    If Not *USB : ProcedureReturn 0 : EndIf
    ProcedureReturn PeekB(*USB\bRX + 2 + Offset)
  EndProcedure
  
  ;}----------------------------------------------------------
EndModule

; #INDEX# =======================================================================================================================
; Compile .........: Компиляция в DLL
; ===============================================================================================================================
CompilerIf #PB_Compiler_DLL And Not #PB_Compiler_Debugger
  
  ProcedureDLL Init()
    ProcedureReturn USB::Init()
  EndProcedure
  
  ProcedureDLL Device(Key.l, PID.u = USB::#PID, VID.u = USB::#VID, TX.l = USB::#TX, RX.l = USB::#RX)
    ProcedureReturn USB::Device(Key.l, PID.u, VID.u, TX.l, RX.l)
  EndProcedure
  
  ProcedureDLL Close(*USB.USB::USB)
    ProcedureReturn USB::Close(*USB)
  EndProcedure
  
  ProcedureDLL ReadD(*USB.USB::USB)
    ProcedureReturn USB::ReadD(*USB)
  EndProcedure
  
  ProcedureDLL WriteD(*USB.USB::USB)
    ProcedureReturn USB::WriteD(*USB)
  EndProcedure
  
  ProcedureDLL WriteRead(*USB.USB::USB)
    ProcedureReturn USB::WriteRead(*USB)
  EndProcedure
  
  ProcedureDLL GetKey(*USB.USB::USB)
    ProcedureReturn USB::GetKey(*USB)
  EndProcedure
  
  ProcedureDLL RunB(*USB.USB::USB, Party.b, Detail1.b = $00, Detail2.b = $00, Detail3.b = $00, Detail4.b = $00, Detail5.b = $00)
    ProcedureReturn USB::RunB(*USB, Party.b, Detail1.b, Detail2.b, Detail3.b, Detail4.b, Detail5.b)
  EndProcedure
  
  ProcedureDLL.b ReadB(*USB.USB::USB, Offset.l = 0)
    ProcedureReturn USB::ReadB(*USB, Offset.l)
  EndProcedure
  
CompilerEndIf

; IDE Options = PureBasic 5.50 (Windows - x86)
; ExecutableFormat = Shared dll
; CursorPosition = 1
; Folding = ZCAA--
; EnableXP
; EnableAdmin
; Executable = Bin\USB.dll
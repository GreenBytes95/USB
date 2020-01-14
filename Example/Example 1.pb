XIncludeFile "..\USB.pb"

USB::Init()
*USB.USB::USB = USB::Device($010066FF)

If Not *USB
  Debug "Not USB"
Else
  Debug "Connect"
EndIf

If Not USB::RunB(*USB, $02, $FF)
  Debug "Not Call RunB"
Else
  Debug "RunB - Ok"
EndIf

If Not USB::RunB(*USB, $05)
  Debug "Not Call RunB"
Else
  Debug "RunB - Ok"
EndIf

Debug "Temp = " + Str(USB::ReadB(*USB, 1))

USB::Close(*USB)
; IDE Options = PureBasic 5.60 (Windows - x86)
; CursorPosition = 3
; EnableXP
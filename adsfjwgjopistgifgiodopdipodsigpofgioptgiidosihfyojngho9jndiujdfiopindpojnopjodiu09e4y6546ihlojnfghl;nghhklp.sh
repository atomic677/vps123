ipconfig /flushdns
netsh winsock reset
netsh int tcp set global autotuninglevel=normal
netsh interface tcp set heuristics disabled

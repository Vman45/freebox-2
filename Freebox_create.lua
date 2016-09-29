do
  local dev = luup.create_device ('', "FBX", "Freebox", "D_Freebox.xml", "I_Freebox.xml")
  print(dev)
end

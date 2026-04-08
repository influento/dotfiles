-- reset-on-eof.lua — Reset to first frame (paused) when file ends

mp.observe_property("eof-reached", "bool", function(_, eof)
  if eof then
    mp.commandv("seek", "0", "absolute")
    mp.set_property_bool("pause", true)
  end
end)

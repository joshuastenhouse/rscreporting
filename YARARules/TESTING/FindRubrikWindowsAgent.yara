//find windows RBS 

rule RBSDetect : WindowsRBS {
    meta:
      description = "Rbs.exe present v2"
      author = "Rich Eicher"    
    strings:
$a = { FD BC 2A 00 FF FF FF FF D1 BC 2A 00 00 00 00 00 }
$b = { 0A 29 11 00 FF FF FF FF 43 29 11 00 00 00 00 00 }
$c = { 6C 29 11 00 02 00 00 00 19 39 0D 00 2B 74 21 00 }

condition:
        any of them
}
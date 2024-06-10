//find linux RBS

rule RBSDetect : LinuxRBS {
    meta:
      description = "Linux RBS present v1"
      author = "Rich Eicher"    
    strings:
$a = { 0F 84 33 02 00 00 8B 54 24 08 83 FA 01 0F 84 4E }
$b = { 04 00 00 8B 44 24 20 89 C6 83 EE 01 0F 88 3F 04 }
$c = { 00 00 41 BF 01 00 00 00 8D 68 FE 29 D0 45 89 FC }

condition:
        any of them
}
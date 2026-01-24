client folder struct → read (SKADI, firewall, IIS) → parse using Docker(win) → ingest to Elastic Docker (Logstash ubuntu) → clean Docker → repeat



client and tools folder struct

dfir_root/
├── tools
│   ├── _tmp (Get-ZimmermanTools.ps1)
│   ├── CyLR
│   │ 	├── CyLR.exe
│   │   └── cylr-win.conf
│   └── eztools
├── scripts/
│   ├── step1_create_client_folders.ps1
│   ├── step2_prepare_tools.ps1
│   ├── step3_Docker ( copy_iis_logs.ps1, firewall_logs_parse_2_json.py, skadi_parse.ps1 )
│   ├── step4_Docker ( Logstash --> elastic )
│   └── step5_cleanup.ps1
├── parsers/
│   └── all_in_one.conf
├── client_data
│   └──<client_name>/
│   	├── submit_skadi/
│   	│   └── <hostname>_skadi.zip
│   	├── network_logs/yyyy-mm-dd
│   	│ 	├── *.log
│   	│ 	├── *.csv
│   	│ 	├── *.txt
│   	│	└── *.json
│   	└── iis_logs/<hostname>
│   	    └── /*/*.log
├── temp
│   └──<client_name>/
│   	├── extracted_skadi/
├── parsed_data
│   └──<client_name>/
│   	├── parsed_skadi/
│   	│   ├── Amcache
│   	│ 	├── EventLogs
│   	│ 	├── JumpList
│   	│ 	├── LNKFiles
│   	│	├── MFT
│   	│ 	├── Prefetch
│   	│ 	├── Registry
│   	│ 	├── Shimcache
│   	│	└── SRUM
│   	├── firewall/
│   	│	└── *.json
│   	└── iis/<hostname>
│   	    └── /*/*.log
├── docker-windows/
│   ├── docker-compose.yml ( copy_iis_logs.ps1, firewall_logs_parse_2_json.py, skadi_parse.ps1 )
│   ├── .env
│   ├── parser/
│   │   └── Dockerfile
├── docker-ubuntu/
│   ├── docker-compose.yml (parsed_data -->logstash --> elastic)
│   ├── .env
│   ├── parser/
│   │   └── Dockerfile         
│   └── logstash/
│       ├── Dockerfile
│       ├── logstash.yml
│       └── pipeline/
│           └── skadi.conf (copy from parsers/all_in_one.conf)
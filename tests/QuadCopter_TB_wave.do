onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider ESCs
add wave -noupdate -radix binary /QuadCopter_tb/TB/frnt_ESC
add wave -noupdate -radix binary /QuadCopter_tb/TB/back_ESC
add wave -noupdate -radix binary /QuadCopter_tb/TB/left_ESC
add wave -noupdate -radix binary /QuadCopter_tb/TB/rght_ESC
add wave -noupdate -divider {Inertial Sensor Lines}
add wave -noupdate -radix binary /QuadCopter_tb/TB/SS_n
add wave -noupdate -radix binary /QuadCopter_tb/TB/INT
add wave -noupdate -radix binary /QuadCopter_tb/TB/SCLK
add wave -noupdate -radix binary /QuadCopter_tb/TB/MOSI
add wave -noupdate -radix binary /QuadCopter_tb/TB/MISO
add wave -noupdate -divider {Bluetooth Lines}
add wave -noupdate -radix binary /QuadCopter_tb/TB/RX
add wave -noupdate -radix binary /QuadCopter_tb/TB/TX
add wave -noupdate -radix hexadecimal /QuadCopter_tb/TB/resp
add wave -noupdate -radix binary /QuadCopter_tb/TB/resp_rdy
add wave -noupdate -radix binary /QuadCopter_tb/TB/clr_resp_rdy
add wave -noupdate -divider {Remote Lines}
add wave -noupdate -radix hexadecimal /QuadCopter_tb/TB/host_cmd
add wave -noupdate -radix unsigned /QuadCopter_tb/TB/data
add wave -noupdate -radix binary /QuadCopter_tb/TB/send_cmd
add wave -noupdate -radix binary /QuadCopter_tb/TB/cmd_sent
add wave -noupdate -divider {Global Signals}
add wave -noupdate -radix binary /QuadCopter_tb/TB/RST_n
add wave -noupdate -radix binary /QuadCopter_tb/TB/clk
add wave -noupdate -divider {Actual - Pitch/Roll/Yaw/Thrust}
add wave -noupdate -format Analog-Step -height 74 -max 173.0 -min -1.0 -radix decimal /QuadCopter_tb/TB/iDUT/ptch
add wave -noupdate -format Analog-Step -height 74 -max 116.0 -min -1.0 -radix decimal /QuadCopter_tb/TB/iDUT/roll
add wave -noupdate -format Analog-Step -height 74 -max 154.0 -radix decimal /QuadCopter_tb/TB/iDUT/yaw
add wave -noupdate -radix unsigned /QuadCopter_tb/TB/iDUT/thrst
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {282855770 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 304
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 2
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {396619313 ps}

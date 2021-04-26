onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /QuadCopter_tb/LED
add wave -noupdate -divider ESCs
add wave -noupdate -radix binary /QuadCopter_tb/frnt_ESC
add wave -noupdate -radix binary /QuadCopter_tb/back_ESC
add wave -noupdate -radix binary /QuadCopter_tb/left_ESC
add wave -noupdate -radix binary /QuadCopter_tb/rght_ESC
add wave -noupdate -divider {Inertial Sensor Lines}
add wave -noupdate -radix binary /QuadCopter_tb/SS_n
add wave -noupdate -radix binary /QuadCopter_tb/INT
add wave -noupdate -radix binary /QuadCopter_tb/SCLK
add wave -noupdate -radix binary /QuadCopter_tb/MOSI
add wave -noupdate -radix binary /QuadCopter_tb/MISO
add wave -noupdate -divider {Bluetooth Lines}
add wave -noupdate -radix binary /QuadCopter_tb/RX
add wave -noupdate -radix binary /QuadCopter_tb/TX
add wave -noupdate -radix hexadecimal /QuadCopter_tb/resp
add wave -noupdate -radix binary /QuadCopter_tb/resp_rdy
add wave -noupdate -radix binary /QuadCopter_tb/clr_resp_rdy
add wave -noupdate -divider {Remote Lines}
add wave -noupdate -radix hexadecimal /QuadCopter_tb/host_cmd
add wave -noupdate -radix hexadecimal /QuadCopter_tb/data
add wave -noupdate -radix binary /QuadCopter_tb/send_cmd
add wave -noupdate -radix binary /QuadCopter_tb/cmd_sent
add wave -noupdate -divider {Global Signals}
add wave -noupdate -radix binary /QuadCopter_tb/RST_n
add wave -noupdate -radix binary /QuadCopter_tb/clk
add wave -noupdate -divider {Actual - Pitch/Roll/Yaw}
add wave -noupdate -radix decimal /QuadCopter_tb/iDUT/ptch
add wave -noupdate -radix decimal /QuadCopter_tb/iDUT/roll
add wave -noupdate -radix decimal /QuadCopter_tb/iDUT/yaw
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4290514 ps} 0}
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
WaveRestoreZoom {0 ps} {10693505 ps}

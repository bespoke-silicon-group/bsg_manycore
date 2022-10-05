from bsg_tag_trace_gen import *
import sys
import math

if __name__ == "__main__":
  num_pods_x = int(sys.argv[1])
  num_pods_y = int(sys.argv[2])

  # each pod has one client for reset
  num_clients = (num_pods_x*num_pods_y)
  payload_width = 1 # reset
  lg_payload_width = int(math.ceil(math.log(payload_width+1,2)))
  max_payload_width = (1<<lg_payload_width)-1
  tg = TagTraceGen(1, num_clients, max_payload_width)


  # reset all bsg_tag_master
  tg.send(masters=0b1,client_id=0,data_not_reset=0,length=0,data=0)
  tg.wait(16)
  
  # client indexing [num_pods_y-1:0][num_pods_x-1:0][S:N]
  # reset all clients
  for i in range(num_clients):
    tg.send(masters=0b1, client_id=i, data_not_reset=0, length=max_payload_width, data=(2**max_payload_width)-1)
    
  # Assert reset on all pods
  for i in range(num_pods_y*num_pods_x):
    tg.send(masters=0b1, client_id=i, data_not_reset=1, length=payload_width, data=0b1)

  # Assert reset on io rtr
  #for i in range(num_pods_x):
  #  client_id = (num_pods_y*num_pods_x) + i
  #  tg.send(masters=0b1, client_id=client_id, data_not_reset=1, length=1, data=0b1)

  # De-assert reset on all pods
  for i in range(num_pods_y*num_pods_x):
    tg.send(masters=0b1, client_id=i, data_not_reset=1, length=payload_width, data=0b0)


  # De-Assert reset on io rtr
  #for i in range(num_pods_x):
  #  client_id = (num_pods_y*num_pods_x) + i
  #  tg.send(masters=0b1, client_id=client_id, data_not_reset=1, length=1, data=0b0)


  tg.wait(16)
  tg.wait(16)
  tg.wait(16)
  tg.wait(16)
  tg.done()

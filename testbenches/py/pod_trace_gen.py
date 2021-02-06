from bsg_tag_trace_gen import *
import sys
import math

if __name__ == "__main__":
  num_pods_x = int(sys.argv[1])
  num_pods_y = int(sys.argv[2])
  wh_cord_width = int(sys.argv[3])

  # each pod has two clients
  # and one for io rtr.
  num_clients = (num_pods_x*num_pods_y*2) + num_pods_x
  payload_width = 1+2 # reset + wh_dest_east_not_west[1:0]
  lg_payload_width = int(math.ceil(math.log(payload_width+1,2)))
  max_payload_width = (1<<lg_payload_width)-1
  tg = TagTraceGen(1, num_clients, max_payload_width)


  # reset all bsg_tag_master
  tg.send(masters=0b1,client_id=0,data_not_reset=0,length=0,data=0)
  tg.wait(32)
  
  # client indexing [num_pods_y-1:0][num_pods_x-1:0][S:N]
  # reset all clients
  for i in range(num_clients):
    tg.send(masters=0b1, client_id=i, data_not_reset=0, length=max_payload_width, data=(2**max_payload_width)-1)
    
  # Assert reset on all pods
  for i in range(num_pods_y*num_pods_x*2):
    tg.send(masters=0b1, client_id=i, data_not_reset=1, length=payload_width, data=0b111)

  # Assert reset on io rtr
  for i in range(num_pods_x):
    client_id = (num_pods_y*num_pods_x*2) + i
    tg.send(masters=0b1, client_id=client_id, data_not_reset=1, length=1, data=0b1)

  # De-assert reset on all pods
  # set dest_wh_cord
  for y in range(num_pods_y):
    for x in range(num_pods_x):
      pod_id = x + (y*num_pods_x)
      north_id = (2*pod_id)
      south_id = (2*pod_id) + 1

      north_data = -1
      south_data = -1

      if num_pods_x == 1:
        # left half of a pod is going west
        # right half of a pod is going east
        north_data = 0b010
        south_data = 0b010
      else:
        # split the traffic in half
        if x < num_pods_x/2:
          # going west
          north_data = 0b000
          south_data = 0b000
        else:
          # going east
          north_data = 0b011
          south_data = 0b011
          
      tg.send(masters=0b1, client_id=north_id, data_not_reset=1, length=payload_width, data=north_data)
      tg.send(masters=0b1, client_id=south_id, data_not_reset=1, length=payload_width, data=south_data)


  # De-Assert reset on io rtr
  for i in range(num_pods_x):
    client_id = (num_pods_y*num_pods_x*2) + i
    tg.send(masters=0b1, client_id=client_id, data_not_reset=1, length=1, data=0b0)


  tg.wait(16)
  tg.done()

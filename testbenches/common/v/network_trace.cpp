#include <string>
#include <vector>
#include <cstdio>
#include <iostream>
#include <fstream>

class NetworkTrace {
  
  public:
    // constructor;
    NetworkTrace(int num_tiles_x, int num_tiles_y):
    _fwd_arr(num_tiles_x*num_tiles_y*2*num_tiles_x,0),
    _rev_arr(num_tiles_x*num_tiles_y*2*num_tiles_x,0),
    _tile_fwd_count(num_tiles_x*num_tiles_y*2*num_tiles_x,0),
    _vc_fwd_count(num_tiles_x*num_tiles_y*2*num_tiles_x,0),
    _vc_rev_count(num_tiles_x*num_tiles_y*2*num_tiles_x,0),
    _tile_rev_count(num_tiles_x*num_tiles_y*2*num_tiles_x,0)
    {
      _num_tiles_x = num_tiles_x;
      _num_tiles_y = num_tiles_y;
      _arr_size = num_tiles_x*num_tiles_y*2*num_tiles_x;
    }

    int get_idx(int tile_x, int tile_y, int vc_x, int vc_y) {
      int vc_y0 = (vc_y == _num_tiles_y-1)
        ? 0 // north;
        : 1; // south;
      int vc_id = (vc_y0*_num_tiles_x)+(vc_x-_num_tiles_x);
      int base_tile_x = tile_x-_num_tiles_x;
      int base_tile_y = tile_y-_num_tiles_y;
      int tile_id = (base_tile_y*_num_tiles_x) + base_tile_x;
      return tile_id*(2*_num_tiles_x) + vc_id;
    }

    void tile_fwd_trace(int ctr, int tile_x, int tile_y, int vc_x, int vc_y) {
      int idx = get_idx(tile_x, tile_y, vc_x, vc_y);
      _fwd_arr[idx] -= ctr;
      //printf("tile_fwd_trace(%d,%d,%d,%d,%d),%d\n", ctr, tile_x, tile_y, vc_x, vc_y, idx);
      _tile_fwd_count[idx] += 1;
    }

    void vc_fwd_trace(int ctr, int tile_x, int tile_y, int vc_x, int vc_y)
    {
      int idx = get_idx(tile_x, tile_y, vc_x, vc_y);
      //printf("vc_fwd_trace(%d,%d,%d,%d,%d),id=%d\n", ctr, tile_x, tile_y, vc_x, vc_y, idx);
      _fwd_arr[idx] += ctr;
      _vc_fwd_count[idx] += 1;
      //printf("vc_fwd_trace(%d,%d,%d,%d,%d),count=%d\n", ctr, tile_x, tile_y, vc_x, vc_y, _vc_fwd_count[idx]);
    }

    void vc_rev_trace(int ctr, int tile_x, int tile_y, int vc_x, int vc_y)
    {
      int idx = get_idx(tile_x, tile_y, vc_x, vc_y);
      _rev_arr[idx] -= ctr;
      _vc_rev_count[idx] += 1;
    }

    void tile_rev_trace(int ctr, int tile_x, int tile_y, int vc_x, int vc_y)
    {
      int idx = get_idx(tile_x, tile_y, vc_x, vc_y);
      _rev_arr[idx] += ctr;
      _tile_rev_count[idx] += 1;
    }

    void finish() 
    {
    
      // dump count;
      std::ofstream tile_fwd_file;
      std::ofstream vc_fwd_file;
      std::ofstream vc_rev_file;
      std::ofstream tile_rev_file;
      tile_fwd_file.open("tile_fwd_count.csv");
      vc_fwd_file.open("vc_fwd_count.csv");
      vc_rev_file.open("vc_rev_count.csv");
      tile_rev_file.open("tile_rev_count.csv");

      int packet_count = 0;
      for (int tile_x = 0; tile_x < _num_tiles_x; tile_x++) {
        for (int tile_y = 0; tile_y < _num_tiles_y; tile_y++) {
          for (int vc_x = 0; vc_x < _num_tiles_x; vc_x++) {
            // north;
            int vc_ny = _num_tiles_y-1;
            int nidx = get_idx(tile_x+_num_tiles_x, tile_y+_num_tiles_y, vc_x+_num_tiles_x, vc_ny);
            tile_fwd_file << tile_x << "," << tile_y << "," << vc_x << "," << vc_ny << "," << _tile_fwd_count[nidx] << std::endl;
            vc_fwd_file   << tile_x << "," << tile_y << "," << vc_x << "," << vc_ny << "," << _vc_fwd_count[nidx]   << std::endl;
            vc_rev_file   << tile_x << "," << tile_y << "," << vc_x << "," << vc_ny << "," << _vc_rev_count[nidx]   << std::endl;
            tile_rev_file << tile_x << "," << tile_y << "," << vc_x << "," << vc_ny << "," << _tile_rev_count[nidx] << std::endl;
            packet_count += _tile_fwd_count[nidx];
            packet_count += _vc_rev_count[nidx];
            // south;
            int vc_sy = _num_tiles_y*2;
            int sidx = get_idx(tile_x+_num_tiles_x, tile_y+_num_tiles_y, vc_x+_num_tiles_x, vc_sy);
            tile_fwd_file << tile_x << "," << tile_y << "," << vc_x << "," << vc_sy << "," << _tile_fwd_count[sidx] << std::endl;
            vc_fwd_file   << tile_x << "," << tile_y << "," << vc_x << "," << vc_sy << "," << _vc_fwd_count[sidx]   << std::endl;
            vc_rev_file   << tile_x << "," << tile_y << "," << vc_x << "," << vc_sy << "," << _vc_rev_count[sidx]   << std::endl;
            tile_rev_file << tile_x << "," << tile_y << "," << vc_x << "," << vc_sy << "," << _tile_rev_count[sidx] << std::endl;
            packet_count += _tile_fwd_count[sidx];
            packet_count += _vc_rev_count[sidx];
          }
        }
      }

      tile_fwd_file.close();
      vc_fwd_file.close();
      vc_rev_file.close();
      tile_rev_file.close();

      // calculate average;
      int total_latency = 0;
      for (int i = 0; i < _arr_size; i++) {
        total_latency += _fwd_arr[i];
        total_latency += _rev_arr[i];
      }
      float average_latency = (float) total_latency / (float) packet_count;
      std::ofstream myfile;
      myfile.open("nt_latency.txt");
      myfile << average_latency << std::endl;
      myfile.close();
    }

  private:
    int _num_tiles_x;
    int _num_tiles_y;
    int _arr_size;
    std::vector<int32_t> _fwd_arr;
    std::vector<int32_t> _rev_arr;
    std::vector<int32_t> _tile_fwd_count;
    std::vector<int32_t> _vc_fwd_count;
    std::vector<int32_t> _vc_rev_count;
    std::vector<int32_t> _tile_rev_count;
};



////////////////////////////////////////////

static NetworkTrace* nt = NULL;


// initialize;
extern "C" void dpi_network_trace_init(int num_tiles_x, int num_tiles_y)
{
  if (nt == NULL) {
    printf("initializing NetworkTrace...\n");
    nt = new NetworkTrace(num_tiles_x, num_tiles_y);
  }
  //return nt;
}



extern "C" void dpi_tile_fwd_trace (int ctr, int tile_x, int tile_y, int vc_x, int vc_y)
{
  nt->tile_fwd_trace(ctr, tile_x, tile_y, vc_x, vc_y);
}


extern "C" void dpi_vc_fwd_trace (int ctr, int tile_x, int tile_y, int vc_x, int vc_y)
{
  nt->vc_fwd_trace(ctr, tile_x, tile_y, vc_x, vc_y);
}

extern "C" void dpi_vc_rev_trace (int ctr, int tile_x, int tile_y, int vc_x, int vc_y)
{
  nt->vc_rev_trace(ctr, tile_x, tile_y, vc_x, vc_y);
}

extern "C" void dpi_tile_rev_trace (int ctr, int tile_x, int tile_y, int vc_x, int vc_y)
{
  nt->tile_rev_trace(ctr, tile_x, tile_y, vc_x, vc_y);
}


// dump and exit;
extern "C" void dpi_network_trace_finish()
{
  nt->finish();
}

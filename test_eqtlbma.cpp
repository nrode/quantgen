/** \file test_eqtlbma.cpp
 *
 *  `test_eqtlbma' tests functions from `eqtlbma'.
 *  Copyright (C) 2012 Timothee Flutre
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  g++ -Wall -Wextra -g utils.cpp test_eqtlbma.cpp -lgsl -lgslcblas -lz -o test_eqtlbma
 */

#include <cmath>
#include <cstring>
#include <ctime>
#include <cstdlib>
#include <cstdio>
#include <getopt.h>

#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <map>
#include <fstream>
#include <algorithm>
#include <limits>
#include <sstream>
#include <numeric>
using namespace std;

#include "utils.h"
#include "eqtlbma.cpp"

void
test_loadSamples_prepData (
  size_t & nbSubgroups,
  size_t & nbSamples,
  vector<string> & vFileNames,
  map<string, string> & mGenoPaths,
  map<string, string> & mPhenoPaths,
  vector<string> & vSubgroups)
{
  ofstream stream;
  
  nbSubgroups = 2;
  vSubgroups.push_back ("s1");
  vSubgroups.push_back ("s2");
  
  nbSamples = 4; // 1,2,3 in s1; 1,4 in s2, 3 w/o genotype, 4 w/o phenotype
  
  // write phenotype file for s1 (only the header)
  vFileNames.push_back ("phenotypes_s1.txt");
  mPhenoPaths["s1"] = vFileNames[0];
  openFile (vFileNames[0], stream);
  stream << "ind1 ind2 ind3" << endl;
  stream.close();
  
  // write phenotype file for s2 (only the header)
  vFileNames.push_back ("phenotypes_s2.txt");
  mPhenoPaths["s2"] = vFileNames[1];
  openFile (vFileNames[1], stream);
  stream << "ind1" << endl;
  stream.close();
  
  // write genotype file for s1 (only the header)
  vFileNames.push_back ("genotypes_s1.imp");
  mGenoPaths["s1"] = vFileNames[2];
  openFile (vFileNames[2], stream);
  stream << "chr rs coord a1 a2"
	 << " ind1_a1a1 ind1_a1a2 ind1_a2a2"
	 << " ind2_a1a1 ind2_a1a2 ind2_a2a2"
	 << endl;
  stream.close();
  
  // write genotype file for s1 (only the header)
  vFileNames.push_back ("genotypes_s2.imp");
  mGenoPaths["s2"] = vFileNames[3];
  openFile (vFileNames[3], stream);
  stream << "chr rs coord a1 a2"
	 << " ind1_a1a1 ind1_a1a2 ind1_a2a2"
	 << " ind4_a1a1 ind4_a1a2 ind4_a2a2"
	 << endl;
  stream.close();
}

void
test_loadSamples_prepExp (
  vector<string> & vSamples_exp,
  vector<vector<size_t> > & vvSampleIdxGenos_exp,
  vector<vector<size_t> > & vvSampleIdxPhenos_exp)
{
  // first samples from phenotypes, then genotypes
  vSamples_exp.push_back ("ind1");
  vSamples_exp.push_back ("ind2");
  vSamples_exp.push_back ("ind3");
  vSamples_exp.push_back ("ind4");
  
  // vvSampleIdxPhenos[3][0] = 5 means that the 1st sample in vSamples
  // corresponds to the 6th sample in the 4th subgroup
  
  // samples from phenotype file for s1
  vvSampleIdxPhenos_exp.push_back (vector<size_t> (vSamples_exp.size(),
						  string::npos));
  vvSampleIdxPhenos_exp[0][0] = 0;
  vvSampleIdxPhenos_exp[0][1] = 1;
  vvSampleIdxPhenos_exp[0][2] = 2;
  
  // samples from phenotype file for s2
  vvSampleIdxPhenos_exp.push_back (vector<size_t> (vSamples_exp.size(),
						  string::npos));
  vvSampleIdxPhenos_exp[1][0] = 0;
  
  // samples from genotype file for s1
  vvSampleIdxGenos_exp.push_back (vector<size_t> (vSamples_exp.size(),
						  string::npos));
  vvSampleIdxGenos_exp[0][0] = 0;
  vvSampleIdxGenos_exp[0][1] = 1;
  
  // samples from genotype file for s2
  vvSampleIdxGenos_exp.push_back (vector<size_t> (vSamples_exp.size(),
						  string::npos));
  vvSampleIdxGenos_exp[1][0] = 0;
  vvSampleIdxGenos_exp[1][3] = 1;
}

void
test_loadSamples_checkOut (
  const vector<string> & vSamples_exp,
  const vector<vector<size_t> > & vvSampleIdxGenos_exp,
  const vector<vector<size_t> > & vvSampleIdxPhenos_exp,
  const vector<string> & vSamples_obs,
  const vector<vector<size_t> > & vvSampleIdxGenos_obs,
  const vector<vector<size_t> > & vvSampleIdxPhenos_obs)
{
  // check vSamples_obs
  if (vSamples_obs.size() != vSamples_exp.size())
  {
    cerr << "ERROR: in " << __FUNCTION__ << endl;
    cerr << "vSamples_obs.size() (" << vSamples_obs.size() << ") != vSamples_exp.size() (" << vSamples_exp.size() << ")" << endl;
    exit (1);
  }
  for (size_t i = 0; i < vSamples_exp.size(); ++i)
    if (vSamples_obs[i].compare(vSamples_exp[i]) != 0)
    {
      cerr << "ERROR: in " << __FUNCTION__ << endl;
      exit (1);
    }
  
  // check vvSampleIdxGenos_obs
  if (vvSampleIdxGenos_obs.size() != vvSampleIdxGenos_exp.size())
  {
    cerr << "ERROR: in " << __FUNCTION__ << endl;
    exit (1);
  }
  for (size_t s = 0; s < vvSampleIdxGenos_exp.size(); ++s)
  {
    if (vvSampleIdxGenos_obs[s].size() != vvSampleIdxGenos_exp[s].size())
    {
      cerr << "ERROR: in " << __FUNCTION__ << endl;
      exit (1);
    }
    for (size_t i = 0; i < vvSampleIdxGenos_exp[s].size(); ++i)
    {
      if (vvSampleIdxGenos_obs[s][i] != vvSampleIdxGenos_exp[s][i])
      {
	cerr << "ERROR: in " << __FUNCTION__ << endl;
	cerr << "vvSampleIdxGenos_obs[" << s << "][" << i << "] (" << vvSampleIdxGenos_obs[s][i] << ") != vvSampleIdxGenos_exp[" << s << "][" << i << "] (" << vvSampleIdxGenos_exp[s][i] << ")" << endl;
	exit (1);
      }
    }
  }
  
  // check vvSampleIdxPhenos_obs
  if (vvSampleIdxPhenos_obs.size() != vvSampleIdxPhenos_exp.size())
  {
    cerr << "ERROR: in " << __FUNCTION__ << endl;
    exit (1);
  }
  for (size_t s = 0; s < vvSampleIdxPhenos_exp.size(); ++s)
  {
    if (vvSampleIdxPhenos_obs[s].size() != vvSampleIdxPhenos_exp[s].size())
    {
      cerr << "ERROR: in " << __FUNCTION__ << endl;
      exit (1);
    }
    for (size_t i = 0; i < vvSampleIdxPhenos_exp[s].size(); ++i)
    {
      if (vvSampleIdxPhenos_obs[s][i] != vvSampleIdxPhenos_exp[s][i])
      {
	cerr << "ERROR: in " << __FUNCTION__ << endl;
	cerr << "vvSampleIdxPhenos_obs[" << s << "][" << i << "] (" << vvSampleIdxPhenos_obs[s][i] << ") != vvSampleIdxPhenos_exp[" << s << "][" << i << "] (" << vvSampleIdxPhenos_exp[s][i] << ")" << endl;
	exit (1);
      }
    }
  }
}

void
test_loadSamples (const int & verbose)
{
  if (verbose > 0)
    cout << "START '" << __FUNCTION__ << "'" << endl << flush;
  
  // prepare input data
  size_t nbSubgroups, nbSamples;
  vector<string> vFileNames, vSubgroups;
  map<string, string> mGenoPaths, mPhenoPaths;
  test_loadSamples_prepData (nbSubgroups, nbSamples, vFileNames, mGenoPaths,
			     mPhenoPaths, vSubgroups);
  
  // prepare the expected outputs
  vector<string> vSamples_exp;
  vector<vector<size_t> > vvSampleIdxGenos_exp, vvSampleIdxPhenos_exp;
  test_loadSamples_prepExp (vSamples_exp, vvSampleIdxGenos_exp,
			    vvSampleIdxPhenos_exp);
  
  // run the function
  vector<string> vSamples_obs;
  vector<vector<size_t> > vvSampleIdxGenos_obs, vvSampleIdxPhenos_obs;
  loadSamples (mGenoPaths, mPhenoPaths, vSubgroups, vSamples_obs,
	       vvSampleIdxGenos_obs, vvSampleIdxPhenos_obs, verbose);
  
  // check the observed outputs
  test_loadSamples_checkOut (vSamples_exp, vvSampleIdxGenos_exp,
			     vvSampleIdxPhenos_exp, vSamples_obs,
			     vvSampleIdxGenos_obs, vvSampleIdxPhenos_obs);
  
  // clean
  removeFiles (vFileNames);
  
  if (verbose > 0)
    cout << "END '" << __FUNCTION__ << "'" << endl << flush;
}

int main (int argc, char ** argv)
{
  int verbose;
  if (argc > 1)
    verbose = atoi (argv[1]);
  else
    verbose = 0;
  
  test_loadSamples (verbose);
  
  return EXIT_SUCCESS;
}

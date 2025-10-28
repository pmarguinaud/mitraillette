#!/usr/bin/env python
# -*- coding: utf-8 -*-

# 1. Blocks to be added.
## new_blocks = set(['NAMXXX','NAMYYY'])
new_blocks = set(['NAMJBHYBACV','NAMSATSIM','NAMTRAJ'])

# 2. Blocks to be moved. If target block exists, elements are moved in the existing block.
## --- none for this cycle ---
## blocks_to_move = {'NAMXXX1':'NAMYYY1',
##                  {'NAMXXX2':'NAMYYY2',
##                  }

# 3. Keys to be moved. If target exists or target block is missing, raise an error.
# Blocks need to be consistent with above blocks movings.
# Change the key from block, and/or rename it
## keys_to_move = {('NAMXXX1', 'NVARXXX1'):('NAMYYY1', 'NVARYYY1'),
##                ('NAMXXX2', 'NVARXXX2'):('NAMYYY2', 'NVARYYY2'),
##                }
keys_to_move = {('NAMCHEM', 'LCHEM_NOXADV'):('NAMCHEM', 'KCHEM_NOXADV'),
               ('NAMACV', 'LTAPER_ACV_WEIGHT'):('NAMJBHYBACV', 'LTAPER_ACV_WEIGHT'),
               ('NAMACV', 'LACV_FILTER_ALPHA'):('NAMJBHYBACV', 'LACV_FILTER_ALPHA'),
               ('NAMACV', 'LACV_LOC_LAP_LNSP'):('NAMJBHYBACV', 'LACV_LOC_LAP_LNSP'),
               ('NAMACV', 'LACV_LOC_LAP_VOD'):('NAMJBHYBACV', 'LACV_LOC_LAP_VOD'),
               ('NAMACV', 'NACV_FILTER_EXP'):('NAMJBHYBACV', 'NACV_FILTER_EXP'),
               ('NAMACV', 'NACV_LOC_VSCALE'):('NAMJBHYBACV', 'NACV_LOC_VSCALE'),
               ('NAMACV', 'RTAPER_ACV_BOTTOM'):('NAMJBHYBACV', 'RTAPER_ACV_BOTTOM'),
               ('NAMACV', 'RACV_FILTER_SCALE'):('NAMJBHYBACV', 'RACV_FILTER_SCALE'),
               ('NAMACV', 'RTAPER_ACV_TOP'):('NAMJBHYBACV', 'RTAPER_ACV_TOP'),
               ('NAMACV', 'RACVS'):('NAMJBHYBACV', 'RACVS'),
               ('NAMVAR', 'LTRAJGP'):('NAMTRAJ', 'LTRAJGP'),
               ('NAMVAR', 'LTRAJHR'):('NAMTRAJ', 'LTRAJHR'),
               ('NAMVAR', 'LREADGPTRAJ'):('NAMTRAJ', 'LREADGPTRAJ'),
               ('NAMVAR', 'LTRAJHR_ALTI'):('NAMTRAJ', 'LTRAJHR_ALTI'),
               ('NAMVAR', 'LTRAJHR_SURF'):('NAMTRAJ', 'LTRAJHR_SURF'),
               }

# 4. Keys to be removed. Already missing keys are ignored.
# Blocks need to be consistent with above movings.
## keys_to_remove = set([('NAMXXX1', 'NVARXXX1'),
##                       ('NAMXXX2', 'NVARXXX2'),
##                       ])
keys_to_remove = set([('NAEAER', 'NTAER'),
                      ('NAEAER', 'NWHTSCAV'),
                      ('NAEAER', 'RVSEDSS'),
                      ('NAEAER', 'RVSEDDU'),
                      ('NAEAER', 'RVSEDOM'),
                      ('NAEAER', 'RVSEDBC'),
                      ('NAEAER', 'RVSEDSU'),
                      ('NAEAER', 'RVDEPSS'),
                      ('NAEAER', 'RVDEPDU'),
                      ('NAEAER', 'RVDEPOM'),
                      ('NAEAER', 'RVDEPBC'),
                      ('NAEAER', 'RVDEPSU'),
                      ('NAEAER', 'RWDEPSS'),
                      ('NAEAER', 'RWDEPDU'),
                      ('NAEAER', 'RWDEPOM'),
                      ('NAEAER', 'RWDEPBC'),
                      ('NAEAER', 'RWDEPSU'),
                      ('NAEPHY', 'LESMOSS'),
                      ('NAEVOL', 'RVSEDVOL'),
                      ('NAEVOL', 'RWDEPVOL'),
                      ('NAMACV', 'LJB_ACV'),
                      ('NAMACV', 'NACV'),
                      ('NAMCOSJO', 'LQVARQC'),
                      ('NAMCOSJO', 'NITERQC'),
                      ('NAMCT0', 'CFCLASS'),
                      ('NAMCT0', 'CTYPE'),
                      ('NAMCUMF', 'RTAU0'),
                      ('NAMFPC', 'MFPSAT'),
                      ('NAMGFL', 'YPHYS_NL'),
                      ('NAMOBS', 'L_OBS_ERR_INCREASE_HRETR'),
                      ('NAMPAR1', 'NSLCOMM_SYNC_LEVEL'),
                      ('NAMSEKF', 'NOBS_SCREEN'),
                      ('NAMSEKF', 'LUSE_SMOS'),
                      ('NAMSEKF', 'SMOS_ERR'),
                      ])

# 5. Keys to be set with a value (new or modified). If block is missing, raise an error.
# Blocks need to be consistent with above movings.
## --- none for this cycle ---
## keys_to_set = {('NAMFPD', 'RLATC'):46.5,
##                ('NAMZZZ', 'DODO(0:3)'):[5,6,7],
##                ('NAMVAR', 'LTRAJGP'):True,
##                ('NAMCT0', 'NPOSTS(50)'):-50,
##                ('NAMZZZ', 'THE_NFPCLI'):3,
##                }

# 6. Blocks to be removed. Already missing blocks are ignored.
### blocks_to_remove = set(['NAMXXX','NAMYYY'])

# 7. Macros: substitutions in the namelist's values. A *None* value ignores
# the substitution (keeps the keyword, to be substituted later on.
macros = {'PERTURB':None,
          }

#!/usr/bin/env python
# -*- coding: utf-8 -*-

# 1. Blocks to be added.
## new_blocks = set(['NAMXXX','NAMYYY'])
#new_blocks = set(['NAMDVISI','NAMDPRECIPS'])

# 2. Blocks to be moved. If target block exists, elements are moved in the existing block.
## --- none for this cycle ---
## blocks_to_move = {'NAMXXX1':'NAMYYY1',
##                  {'NAMXXX2':'NAMYYY2',
##                  }

# 3. Keys to be moved. If target exists or target block is missing, raise an error.
# Blocks need to be consistent with above blocks movings.
# Change the key from block, and/or rename it
## keys_to_move = {('NAMFPD', 'RFPBSCAL'):('NAMFPC', 'RFPBSCAL'),
##                ('NAMDYN', 'LDRY_ECMWF'):('NAMDYNA', 'LDRY_ECMWF'),
##                }
## keys_to_move = {('NAMXXX1', 'NVARXXX1'):('NAMYYY1', 'NVARYYY1'),
##                ('NAMXXX2', 'NVARXXX2'):('NAMYYY2', 'NVARYYY2'),
##                }

# 4. Keys to be removed. Already missing keys are ignored.
# Blocks need to be consistent with above movings.
## keys_to_remove = set([('NAMXXX1', 'NVARXXX1'),
##                       ('NAMXXX2', 'NVARXXX2'),
##                       ])

# 5. Keys to be set with a value (new or modified). If block is missing, raise an error.
# Blocks need to be consistent with above movings.
## --- none for this cycle ---
keys_to_set = {('NAMGFL', 'YQ_NL%LQM'):.FALSE.,
                ('NAMGFL', 'YQ_NL%LQMH'):.FALSE.,
                ('NAMGFL', 'YI_NL%LQM'):.FALSE.,
                ('NAMGFL', 'YI_NL%LQMH'):.FALSE.,
                ('NAMGFL', 'YL_NL%LQM'):.FALSE.,
                ('NAMGFL', 'YL_NL%LQMH'):.FALSE.,
                ('NAMGFL', 'YR_NL%LQM'):.FALSE.,
                ('NAMGFL', 'YR_NL%LQMH'):.FALSE.,
                ('NAMGFL', 'YS_NL%LQM'):.FALSE.,
                ('NAMGFL', 'YS_NL%LQMH'):.FALSE.,
                ('NAMGFL', 'YTKE_NL%LQM'):.FALSE.,
                ('NAMGFL', 'YTKE_NL%LQMH'):.FALSE.,
                }

# 6. Blocks to be removed. Already missing blocks are ignored.
### blocks_to_remove = set(['NAMXXX','NAMYYY'])

# 7. Macros: substitutions in the namelist's values. A *None* value ignores
# the substitution (keeps the keyword, to be substituted later on.
macros = {'PERTURB':None,
          }

.section ".word"
   /* Game state memory locations */
  .equ CURR_STATE, 0x90001000       /* Current state of the game */
  .equ GSA_ID, 0x90001004           /* ID of the GSA holding the current state */
  .equ PAUSE, 0x90001008            /* Is the game paused or running */
  .equ SPEED, 0x9000100C            /* Current speed of the game */
  .equ CURR_STEP,  0x90001010       /* Current step of the game */
  .equ SEED, 0x90001014             /* Which seed was used to start the game */
  .equ GSA0, 0x90001018             /* Game State Array 0 starting address */
  .equ GSA1, 0x90001058             /* Game State Array 1 starting address */
  .equ CUSTOM_VAR_START, 0x90001200 /* Start of free range of addresses for custom vars */
  .equ CUSTOM_VAR_END, 0x90001300   /* End of free range of addresses for custom vars */
  .equ RANDOM, 0x40000000           /* Random number generator address */
  .equ LEDS, 0x50000000             /* LEDs address */
  .equ SEVEN_SEGS, 0x60000000       /* 7-segment display addresses */
  .equ BUTTONS, 0x70000004          /* Buttons address */

  /* States */
  .equ INIT, 0
  .equ RAND, 1
  .equ RUN, 2

  /* Colors (0bBGR) */
  .equ RED, 0x100
  .equ BLUE, 0x400

  /* Buttons */
  .equ JT, 0x10
  .equ JB, 0x8
  .equ JL, 0x4
  .equ JR, 0x2
  .equ JC, 0x1
  .equ BUTTON_2, 0x80
  .equ BUTTON_1, 0x20
  .equ BUTTON_0, 0x40

  /* LED selection */
  .equ ALL, 0xF

  /* Constants */
  .equ N_SEEDS, 4           /* Number of available seeds */
  .equ N_GSA_LINES, 10       /* Number of GSA lines */
  .equ N_GSA_COLUMNS, 12    /* Number of GSA columns */
  .equ MAX_SPEED, 10        /* Maximum speed */
  .equ MIN_SPEED, 1         /* Minimum speed */
  .equ PAUSED, 0x00         /* Game paused value */
  .equ RUNNING, 0x01        /* Game running value */

.section ".text.init"
  .globl main

main:
  li sp, CUSTOM_VAR_END       /* Set stack pointer, grows downwards */  

  jal reset_game              /* Reset game */
  mv s1, a0                   /* Set the done variable */
  jal get_input               /* Get input */
  mv s0, a0                   /* Copy the input buttons into s0 */

  not_done:
    bne s1, zero, main        /* If done, go back to main */
    jal select_action         /* Select the action based on input */

    mv a0, s0                 /* Move the copy of the buttons into argument */
    jal update_state          /* Update state based on buttons */

    jal update_gsa            /* Update the GSA */
    jal clear_leds            /* Clear leds */
    jal mask                  /* Put the mask */
    jal draw_gsa              /* Draw the GSA */
    jal wait                  /* Wait */

    jal decrement_step        /* Decrement step */
    mv s1, a0                 /* Store the return value into variable done */
    
    jal get_input             /* Get input */
    mv s0, a0                 /* Set the input variable into s0 */
    j not_done                /* While not done, loop */

/* BEGIN:clear_leds */
clear_leds:
  li t0, RED              /* Load red value to t0 */
  addi t0, t0, BLUE       /* Add the blue value to t0 */ 
  addi t0, t0, 0xFF       /* Select all rows and all columns and add them to t0 */
  la t1, LEDS             /* Load LEDS address to a temporary */
  sw t0, 0(t1)            /* Store t0 to LEDS address */
  ret                     /* return nothing, and go back */
/* END:clear_leds */

/* BEGIN:set_pixel */
set_pixel:
  li t0, RED          /* Load red value to t0 */

  slli t1, a1, 4      /* Shift the y-coordinate by 4 */
  add t0, t0, t1      /* Add the shifted y-coordinate to the red variable */
  add t0, t0, a0      /* Add the x-coordinate to the red variable */

  addi t1, zero, 1    /* Set the value to 1 (ON) */
  slli t1, t1, 16     /* Shift the ON value by 16 */
  add t0, t0, t1      /* Add the ON value to the red variable */

  la t1, LEDS         /* Load the address of LEDS to t1 */
  sw t0, 0(t1)        /* Store the new LED array to LEDS address */

  ret                 /* return nothing, and go back */
/* END:set_pixel */

/* BEGIN:wait */
wait:
  addi t0, zero, 0x400            /* Set the counter in t0 to delay time */
  la t1, SPEED                    /* Load address of game speed to t1 */
  lw t2, 0(t1)                    /* Load the game speed into t2 */
  
  decrement_delay:                  /* Start the decrementing */
    sub t0, t0, t2                  /* Decrement by the game speed value */
    blt zero, t0, decrement_delay   /* While the delay does not equal 0, keep looping */
  
  ret                               /* Return nothing, and go back */
/* END:wait */

/* BEGIN:set_gsa */
set_gsa:
  la t0, GSA_ID             /* Load the GSA ID address into t0 */
  lw t1, 0(t0)              /* Load the GSA ID into t1 */

  beq t1, zero, set_gsa_0   /* If the ID is 0, then get GSA 0 address */
  bne t1, zero, set_gsa_1   /* If the ID is not 0 (1), then get GSA 1 address */

  set_gsa_0:                /* Get the GSA 0 */
    la t0, GSA0             /* Load the address of GSA 0 to t0 */
    j finish_set_gsa        /* Go to the end of the function */

  set_gsa_1:                /* Get the GSA 1 */
    la t0, GSA1             /* Load the address of GSA 1 to t0 */
    
  finish_set_gsa:
    slli t1, a1, 2          /* Shift the y-coordinate by 2 (multiply by 4) */
    add t0, t0, t1          /* Add the y-coordinate into GSA address */
    sw a0, 0(t0)            /* Store the GSA */

  ret                       /* Return nothing, and go back */
/* END:set_gsa */

/* BEGIN:get_gsa */
get_gsa:
  la t0, GSA_ID             /* Load the GSA ID address into t0 */
  lw t1, 0(t0)              /* Load the GSA ID into t1 */

  beq t1, zero, get_gsa_0   /* If the ID is 0, then get GSA 0 address */
  bne t1, zero, get_gsa_1   /* If the ID is not 0 (1), then get GSA 1 address */

  get_gsa_0:                /* Get the GSA 0 */
    la t0, GSA0             /* Load the address of GSA0 to t0 */
    j finish_get_gsa        /* Go to the end of the function */

  get_gsa_1:                /* Get the GSA 1 */
    la t0, GSA1             /* Load the address of GSA1 to t0 */
    
  finish_get_gsa:           /* Get the GSA after getting the address */
    slli t1, a0, 2          /* Shift the y-coordinate by 2 (multiply by 4) */
    add t0, t0, t1          /* Add the y-coordinate into the address */
    lw a0, 0(t0)            /* Load the GSA address into a0 to pass it back */

  ret                       /* Return nothing, and go back */
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:
  addi sp, sp, -24     /* Decrement SP by 24 */
  sw ra, 0(sp)         /* Store return address */
  sw s0, 4(sp)
  sw s1, 8(sp)
  sw s2, 12(sp)
  sw s3, 16(sp)
  sw s4, 20(sp)

  li s0, N_GSA_COLUMNS  /* Set the max value of the inner loop (Number of columns - 12) into t0 */
  li s1, N_GSA_LINES    /* Set the max value of the outer loop (Number of lines - 10) into t1 */

  mv s4, zero           /* Set y coordinate to 0 and use it as counter */

  loop_through_gsa:      /* Loop 10 times through all GSA elements */
    mv a0, s4            /* Set the y-coordinate into a0 as argument */
    jal get_gsa          /* Get the GSA */

    mv s2, zero          /* Set second counter (s2) to 0 */
    mv s3, a0            /* Store the GSA in s3 */

    loop_through_element:                 /* Loop 12 times through each GSA bit */
      andi t0, s3, 1                      /* Get last bit of GSA */
      beq t0, zero, finish_element_loop   /* Set pixel if last bit is 1 else skip it */

      mv a0, s2                           /* Place the x-coordinate into a0 */
      mv a1, s4
      jal set_pixel                       /* Set the pixel */

      finish_element_loop:                /* Finish looping */
        srli s3, s3, 1                    /* Shift by one the GSA */
        addi s2, s2, 1                    /* Increment second counter by one */
        blt s2, s0, loop_through_element  /* If counter (t2) < number of columns (t0) then continue, else repeat */

  addi s4, s4, 1                  /* Increment counter and y-coordinate by one */
  blt s4, s1, loop_through_gsa    /* If counter (a1) < number of lines (t1) then continue, else repeat */
  
  lw ra, 0(sp)                      /* Get the return address back */
  lw s0, 4(sp)
  lw s1, 8(sp)
  lw s2, 12(sp)
  lw s3, 16(sp)
  lw s4, 20(sp)
  addi sp, sp, 24                   /* Increment back the stack pointer */
  ret                               /* Return nothing, and go back */
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:
  addi sp, sp, -16              /* Decrement SP by 4 */
  sw ra, 0(sp)                  /* Store return address */
  sw s0, 4(sp)
  sw s1, 8(sp)
  sw s2, 12(sp)

  li s0, N_GSA_COLUMNS  /* Set the max value of the inner loop (Number of columns - 12)*/
  li s1, N_GSA_LINES    /* Set the max value of the outer loop (Number of lines - 10) */
  la s2, RANDOM         /* Load RANDOM address */

  mv a1, zero           /* Set y coordinate to 0 and use it as counter */

  construct_gsa_column:     /* Loop 10 times through all GSA elements */
    mv t0, zero             /* Set second counter (t0) to 0 */
    mv t1, zero             /* Inicialize GSA */

    construct_gsa_row:                  /* Loop 12 times through each GSA bit */
      lw t2, 0(s2)                      /* Load the random number into t5 */
      slli t1, t1, 1                    /* Shift by one the GSA */
      
      andi t2, t2, 1                    /* Get last bit of the random number */
      or t1, t1, t2                     /* Put the last bit in GSA */

      addi t0, t0, 1                    /* Increment second counter by one */
      blt t0, s0, construct_gsa_row     /* If counter (t2) < number of columns (t0) then continue, else repeat */

  mv a0, t1                          /* Move the GSA into argument a0 */
  jal set_gsa                        /* Set the GSA */

  addi a1, a1, 1                     /* Increment counter and y-coordinate by one */
  blt a1, s1, construct_gsa_column   /* If counter (a1) < number of lines (t1) then continue, else repeat */

  lw ra, 0(sp)                   /* Get the return address back */
  lw s0, 4(sp)
  lw s1, 8(sp)
  lw s2, 12(sp)
  addi sp, sp, 16                /* Increment back the stack pointer */
  ret                            /* Return nothing, jump back */
/* END:random_gsa */

/* BEGIN:change_speed */
change_speed:
  la t0, SPEED                    /* Load address of SPEED into t0 */
  lw t1, 0(t0)                    /* Load the current spped into t1 */

  beq a0, zero, increment_speed   /* If the argument is 0, then increment speed */
  bne a0, zero, decrement_speed   /* If the argument is 1, then decrement speed */

  increment_speed:                /* Increment speed branch */
    li t2, MAX_SPEED              /* Load the MAX SPEED into t2 */
    bge t1, t2, end_change_speed  /* If the current speed is higher or equal than max then end the function */ 

    addi t1, t1, 1                /* Add one to current speed */
    sw t1, 0(t0)                  /* Store the new speed */
    j end_change_speed            /* Jump to the end of the function */
  
  decrement_speed:                /* Decrement speed branch */
    li t2, MIN_SPEED              /* Load the MIN SPEED into t2 */
    bge t2, t1, end_change_speed  /* If the current speed is lower or equal than min then end the function */

    addi t1, t1, -1               /* Subtract one from current speed */
    sw t1, 0(t0)                  /* Store the new speed */

  end_change_speed:               /* End function */
  ret                             /* Return nothing, jump back */
/* END:change_speed */

/* BEGIN:pause_game */
pause_game:
  la t0, PAUSE          /* Load the address of PAUSE */
  lw t1, 0(t0)          /* Load the value of PAUSE into t0 */

  xori t1, t1, 1        /* Change the bit value */
  sw t1, 0(t0)          /* Store the changed value back */
  ret                   /* Return nothing, jump back */
/* END:pause_game */

/* BEGIN:change_steps */
change_steps:
  la t0, CURR_STEP                     /* Load address of STEPS */
  lw t1, 0(t0)                         /* Load value of CURRENT_STEP into t1 */

  add t1, t1, a0                       /* Else add one to units */

  slli a1, a1, 4                       /* Shift the argument by 4 */
  add t1, t1, a1                       /* Add it to the hudnreds */

  slli a2, a2, 8                       /* Shift the argument by 8 */
  add t1, t1, a2                      /* Add it to the hundreds */

  sw t1, 0(t0)                         /* Store the value */
  ret                                  /* Return nothing, jump back */
/* END:change_steps */

/* BEGIN:set_seed */
set_seed:
  addi sp, sp, -12                /* Decrement SP by 12 */
  sw ra, 0(sp)                    /* Store the return address */
  sw s0, 4(sp)                    /* Store s0 */
  sw s1, 8(sp)                    /* Store s1 */
  
  la t0, SEEDS                    /* Load the address of seeds */
  slli t1, a0, 2                  /* Shift the argument by 2 */
  add t0, t0, t1                  /* Add it to the address */
  lw s0, 0(t0)                    /* Load the current seed */

  mv a1, zero                     /* Set counter and y-coordinate a1 to zero */
  addi s1, zero, N_GSA_LINES      /* Set t1 to the number of GSA lines */
  
  set_seed_to_gsa:                /* Loop through seed lines to be put in the GSA */
    lw a0, 0(s0)                  /* Load the GSA element into a0 as argument */
    jal set_gsa                   /* Set the GSA */

    addi s0, s0, 4                /* Increment the address of seed by 4 to get the next element */
    addi a1, a1, 1                /* Increment counter and y-coordinate by 1 */
    blt a1, s1, set_seed_to_gsa   /* If the counter is smaller than number of lines, continue */
  
  lw ra, 0(sp)                    /* Load the return address */
  lw s0, 4(sp)                    /* Load back t0 */
  lw s1, 8(sp)                    /* Load back t1 */
  addi sp, sp, 12                 /* Increment SP back by 12 */
  ret                             /* Return nothig and jump back */
/* END:set_seed */

/* BEGIN:increment_seed */      
increment_seed:
  addi sp, sp, -4               /* Decrement SP by 4 */
  sw ra, 0(sp)                  /* Store the return address */

  la t0, SEED                   /* Load the current seed address */
  li t1, N_SEEDS                /* Load the number of seeds */
  lw t2, 0(t0)                  /* Load the current seed */
  addi t2, t2, 1                /* Increment seed by one */
  blt t2, t1, set_next_seed     /* If the next seed < number of seeds, increase it */

  sw t1, 0(t0)                  /* Store number 4 to SEED */
  jal random_gsa                /* Make a random GSA */
  j end_increment_seed          /* End the function */

  set_next_seed:
    sw t2, 0(t0)                /* Store incremented seed */
    mv a0, t2                   /* Set the argument to the next seed */
    jal set_seed                /* Set the new seed */

  end_increment_seed:
    lw ra, 0(sp)                /* Load the return address */
    addi sp, sp, 4              /* Increment SP back */
  ret                           /* Return nothig and jump back */
/* END:increment_seed */

/* BEGIN:update_state */
update_state:
  addi sp, sp, -4                   /* Decrement the SP by 20 */
  sw ra, 0(sp)                       /* Store the return address */

  la t0, CURR_STATE                  /* Load address of the current state */
  lw t1, 0(t0)                       /* Load the current state into t1 */
  li t2, RUN                         /* Load the value of RUN */
  beq t1, t2, run_state_verify       /* Branch if the current state is run */

  li t3, JR                          /* Load the value of JR */
  and t3, t3, a0                     /* Look if JR was pressed */
  bne t3, zero, jr_button_init_rand  /* If JR was pressed */

  li t2, RAND                        /* Load the value of RAND */
  beq t1, t2, end_update_state       /* End if the current state is rand */

  li t3, JC                          /* Load the JC button value */
  and t3, t3, a0                     /* Check if jc was pressed */
  beq t3, zero, end_update_state     /* If jc is not pressed, skip it */

  la t1, SEED                        /* Load the seed address */
  lw t3, 0(t1)                       /* Load the current seed */
  li t1, N_SEEDS                     /* Load the number of seeds */
  blt t3, t1, end_update_state       /* Seed < N_SEED then skip, else change state to rand */

  sw t2, 0(t0)                       /* Store RAND into current state */
  j end_update_state                 /* Jump to the end of the function */

  jr_button_init_rand:               /* If jr is pressed in init or rand state */
    sw t2, 0(t0)                     /* Change state to RUN */
    la t0, PAUSE                     /* Load the address of PAUSE */
    li t1, RUNNING                   /* Load the value of running */
    sw t1, 0(t0)                     /* Put the value of game to running */
    j end_update_state               /* Jump to the end of the function */

  run_state_verify:
    la t0, CURR_STEP                 /* Load the current step address */
    lw t1, 0(t0)                     /* Load the current step */
    bne t1, zero, jb_button_run      /* If its not zero continue to jb button */

    jal reset_game                   /* If the step is 0 then reset game */
    j end_update_state               /* End the function */

  jb_button_run:                     /* If jb is pressed in run state */
    li t1, JB                        /* Load the value of JB */
    and t1, t1, a0                   /* Check if jb was pressed */
    beq t1, zero, end_update_state   /* If not pressed, end */

    jal reset_game                   /* Reset the game */    

  end_update_state:                  /* End the update state function */
    lw ra, 0(sp)                     /* Load back the return address */
    addi sp, sp, 4                   /* Increment back the SP */
  ret                                /* Return nothig and jump back */
/* END:update_state */

/* BEGIN:select_action */
select_action:
  addi sp, sp, -4                /* Decrement SP by 8 */
  sw ra, 0(sp)                   /* Store the return address */
  
  beq a0, zero, end_select_action    /* If no buttons were pressed, skip */

  la t0, CURR_STATE              /* Load address of the current state */
  lw t1, 0(t0)                   /* Load the current state into t1 */

  li t0, RUN                     /* Load the value of RUN */
  beq t0, t1, run_state          /* Branch if the current state is run */
  
  init_rand_state:                 /* If the game is in INIT or RAND state */
    li t0, JC                      /* Load the JC button value */
    and t0, t0, a0                 /* Check if jc was pressed */
    beq t0, zero, change_buttons   /* If jc is not pressed, skip it */

    jal increment_seed             /* Increment the seed */
    j end_select_action            /* End the function */

  change_buttons:              /* Continue, look for buttons */
    li t0, BUTTON_2            /* Load value of button 2 */
    and t1, t0, a0             /* Check if button was pressed */
    slt a2, zero, t1           /* Set argument if button was pressed */
    
    li t0, BUTTON_1            /* Load value of button 1 */
    and t1, t0, a0             /* Check if button was pressed */
    slt a1, zero, t1           /* Set argument if button was pressed */

    li t0, BUTTON_0            /* Load value of button 0 */
    and t1, t0, a0             /* Check if button was pressed */
    slt a0, zero, t1           /* Set argument if button was pressed */
                
    jal change_steps           /* Change steps according to buttons */

  j end_select_action          /* Jump to the end of the function */

  run_state:                   /* If the game is in RUN state */
    li t0, JC                  /* Load the value of JC */
    and t0, t0, a0             /* Check if JC was pressed */
    beq t0, zero, jr_run       /* If not pressed go to the next one */

    jal pause_game             /* Pause or resume the game */
    j end_select_action        /* Jump to the end of the function */

  jr_run:
    li t0, JR                  /* Load the value of JR */
    and t0, t0, a0             /* Check if JR was pressed */
    beq t0, zero, jl_run       /* If not pressed go to the next one */

    mv a0, zero                /* Set a0 to increase speed */
    jal change_speed           /* Decrease speed */
    j end_select_action        /* Jump to the end of the function */

  jl_run:
    li t0, JL                  /* Load the value of JL */
    and t0, t0, a0             /* Check if JL was pressed */
    beq t0, zero, jt_run       /* If not pressed go to the next one */

    addi a0, zero, 1           /* Set a0 to decrease speed */
    jal change_speed           /* Increase speed */
    j end_select_action        /* Jump to the end of the function */

  jt_run:
    li t0, JT                         /* Load the value of JT */
    and t0, t0, a0                    /* Check if JT was pressed */
    beq t0, zero, end_select_action   /* If not pressed end the function */

    jal random_gsa                    /* Set a random gsa */

  end_select_action:             /* End the update state function */
    lw ra, 0(sp)                 /* Load back the return address */
    addi sp, sp, 4               /* Increment back the SP */
  ret                            /* Return back */
/* END:select_action */

/* BEGIN:cell_fate */
cell_fate:
  addi sp, sp, -4                /* Decrement SP by 4 */
  sw t0, 0(sp)                   /* Store t0 into memory */

  beq a1, zero, dead_state       /* If argument is 0 go to dead state */

  alive_state:                   /* Else if the cell is alive */
    addi t0, zero, 2             /* Set temporary to 2 */
    blt a0, t0, next_step_dead   /* If less than two neighbours */

    addi t0, zero, 3             /* Set temporary to 3 */
    blt t0, a0, next_step_dead   /* If more than three neighbours */

    j next_step_alive            /* Else stays alive */       

  dead_state:                    /* When the cell is dead */   
    addi t0, zero, 3             /* Set temporary to three */
    beq t0, a0, next_step_alive  /* If cell has three neighbours */

  next_step_dead:                /* Set the cell to dead */
    mv a0, zero                  /* Make the dead cell alive */
    j end_cell_fate              /* End the function */

  next_step_alive:               /* Set the cell to alive */
    addi a0, zero, 1             /* Make the dead cell alive */

  end_cell_fate:                 /* End the update state function */
    lw t0, 0(sp)                 /* Load back t0 from memory */
    addi sp, sp, 4               /* Increment back the SP */
  ret                            /* Return back */
/* END:cell_fate */

/* BEGIN:find_neighbours */
find_neighbours:
  addi sp, sp, -28               /* Decrement sp */
  sw ra, 0(sp)                   /* Store return address */
  sw s0, 4(sp)                   /* Store s0 */
  sw s1, 8(sp)                   /* Store s1 */
  sw s2, 12(sp)                  /* Store s2 */
  sw s3, 16(sp)                  /* Store s3 */
  sw s4, 20(sp)                  /* Store s4 */
  sw s5, 24(sp)                  /* Store s5 */

  mv s0, a0                      /* Keep the x-coordinate in s0 */
  mv s1, a1                      /* Keep the y-coordinate in s1 */
  mv s2, zero                    /* Set the counter of neighbours to zero in s2 */
  addi s3, zero, -1              /* Set the index of outer loop to -1 */

  neighbours_y:
    addi s4, zero, -1            /* Set the index of inner loop to -1 */
    add a0, s1, s3               /* Set the y-coordinate to argument */
    li t0, N_GSA_LINES           /* Get the number of lines */
    
    blt a0, zero, modulo_10_neg  /* Add 10 if x is negative */
    bge a0, t0, modulo_10_pos    /* Subtract 10 if x is bigger than max */

    get_neighbour_gsa:
      jal get_gsa                  /* Get the gsa */
      li t0, N_GSA_COLUMNS         /* Get the number of columns */
      j neighbours_x               /* Go to x-coordinate */

    modulo_10_neg:
      addi a0, a0, 10            /* Add 10 to argument */
      j get_neighbour_gsa        /* Go back to the get gsa */

    modulo_10_pos:
      addi a0, a0, -10           /* Subtract 10 from argument */
      j get_neighbour_gsa        /* Go back to the get gsa */

    neighbours_x:
      add t1, s0, s4                      /* Compute the x-coordinate */
      blt t1, zero, modulo_12_neg         /* Add 12 if x is negative */
      bge t1, t0, modulo_12_pos           /* Subtract 12 if x is bigger than max */
      j continue_neighbour_x              /* Else continue */
      
      modulo_12_neg:
        addi t1, t1, 12                   /* Add 12 to argument */
        j continue_neighbour_x            /* Continue with x coordinate */

      modulo_12_pos:
        addi t1, t1, -12                  /* Subtract 12 from argument */

      continue_neighbour_x:
        srl t1, a0, t1                    /* Shift gsa by x to get bit */
        andi t1, t1, 1                    /* Get lsb of correct coordinate */
        bne s4, zero, not_examined_cell   /* Check if x matches the current cell */
        bne s3, zero, not_examined_cell   /* Check if y matches the current cell */

        mv s5, t1                         /* Set the state of the examnied cell */
        mv t1, zero                       /* Set t1 to zero (not a neighbour) */
      
      not_examined_cell: 
        add s2, s2, t1             /* Add the last bit to neighbours */ 
        addi s4, s4, 1             /* Increment inner index */
        addi t1, zero, 2           /* Set the condition of the loop */
        blt s4, t1, neighbours_x   /* If s4 < 2 then keep looping */

    addi s3, s3, 1                 /* Increment counter of outer loop */
    addi t0, zero, 2               /* Set the condition of the loop */
    blt s3, t0, neighbours_y       /* Keep looping while index < 2 */

  mv a0, s2                      /* Return the number of neighbours */
  mv a1, s5                      /* Return examined cell state */

  lw ra, 0(sp)                   /* Load back return address */
  lw s0, 4(sp)                   /* Load back s0 */
  lw s1, 8(sp)                   /* Load back s1 */
  lw s2, 12(sp)                  /* Load back s2 */
  lw s3, 16(sp)                  /* Load back s3 */
  lw s4, 20(sp)                  /* Load back s4 */
  lw s5, 24(sp)                  /* Load back s4 */
  addi sp, sp, 28                /* Increment back sp */
  ret                            /* Return */
/* END:find_neighbours */

/* BEGIN:update_gsa */
update_gsa:
  la t0, PAUSE                    /* Load the address of PAUSE */
  lw t1, 0(t0)                    /* Load PAUSE */
  li t0, PAUSED                   /* Load the value of paused */
  beq t0, t1, update_gsa_end      /* If the game is paused, do nothing */

  la t0, CURR_STATE               /* Load the address of the current state */
  lw t1, 0(t0)                    /* Load the current state */
  li t0, RUN                      /* Load the value of RUN */
  bne t0, t1, update_gsa_end      /* If not in run state then skip */

  addi sp, sp, -28                /* Decrement sp */
  sw ra, 0(sp)                    /* Store the return address */
  sw s0, 4(sp)                    /* Store s0 */
  sw s1, 8(sp)                    /* Store s1 */
  sw s2, 12(sp)                   /* Store s2 */
  sw s3, 16(sp)                   /* Store s3 */
  sw s4, 20(sp)                   /* Store s4 */
  sw s5, 24(sp)                   /* Store s5 */

  la s5, GSA_ID                   /* Load the address of the GDA_ID */
  lw s0, 0(s5)                    /* Load the current GSA_ID in use */
  xori s1, s0, 1                  /* Set s1 to the opposite GSA_ID */

  li s2, N_GSA_LINES              /* Set counter of outer loop to N of Lines - 1 */
  addi s2, s2, -1

  outer_loop_gsa:
    li s3, N_GSA_COLUMNS          /* Set the counter of inner loop */
    addi s3, s3, -1
    mv s4, zero                   /* Next GSA state */

    inner_loop_gsa:
      mv a0, s3                   /* Set the x-coordinate */
      mv a1, s2                   /* Set the y-coordinate */
      jal find_neighbours         /* Find neighbours */
      jal cell_fate               /* Decide the cell fate */

      slli s4, s4, 1              /* Shift the GSA by one */
      add s4, s4, a0              /* Set next (x, y) */
      
      addi s3, s3, -1             /* Increment index by one */
      bge s3, zero, inner_loop_gsa   /* If index < N_COLUMNS then keep looping */

    sw s1, 0(s5)                  /* Set GSA_ID to the opposite */
    mv a0, s4                     /* Set argument to next GSA line */
    mv a1, s2                     /* Set second argument to y-coordinate */
    jal set_gsa                   /* Set new GSA */

    sw s0, 0(s5)                  /* Store back the current GSA_ID */
    addi s2, s2, -1               /* Decrement index by one */
    bge s2, zero, outer_loop_gsa  /* If index < N_LINES then keep looping */

  sw s1, 0(s5)                    /* Set GSA_ID to the opposite */

  lw ra, 0(sp)                    /* Load back the return address */
  lw s0, 4(sp)                    /* Load back s0 */
  lw s1, 8(sp)                    /* Load back s1 */
  lw s2, 12(sp)                   /* Load back s2 */
  lw s3, 16(sp)                   /* Load back s3 */
  lw s4, 20(sp)                   /* Load back s4 */
  lw s5, 24(sp)                   /* Load back s5 */
  addi sp, sp, 28                 /* Increment back sp */

  update_gsa_end:
  ret                             /* Return */  
/* END:update_gsa */

/* BEGIN:get_input */
get_input:
  la t0, BUTTONS                  /* Load the address of BUTTONS */
  lw t1, 0(t0)                    /* Load buttons value */
  andi t1, t1, 0x3FF              /* Get the last 10 bits */
  beq t1, zero, get_input_end     /* If no button was pressed, end */

  mv t2, zero                     /* Set loop index */
  addi t3, zero, 10               /* Set max of the loop */
  loop_through_buttons:
    bge t2, t3, get_input_end     /* If all buttons checked, end */
    srl t4, t1, t2                /* Shift buttons by index */
    andi t4, t4, 1                /* Get the lsb of shifted buttons */
    bne t4, zero, clear_buttons   /* If a button was set, end */
    addi t2, t2, 1                /* Increment index */
    j loop_through_buttons        /* Else keep looping */

  clear_buttons:
    sw zero, 0(t0)                /* Clear buttons */
    addi t1, zero, 1              /* Set lsb to one */
    sll t1, t1, t2                /* Shift lsb to the position of first pressed button */

  get_input_end:
    mv a0, t1                     /* Set the argument to be passed */
  ret                             /* Return */
/* END:get_input */

/* BEGIN:decrement_step */
decrement_step:
  mv a0, zero                     /* Set a0 to zero */

  la t0, CURR_STATE               /* Load the current state address */
  lw t1, 0(t0)                    /* Load the current state */
  li t2, RUN                      /* Load the value of RUN */
  bne t2, t1, put_to_seg          /* If not in RUN state, end */

  la t0, PAUSE                    /* Load the pause address */
  lw t1, 0(t0)                    /* Load the pause value */
  li t0, RUNNING                  /* Load the value of RUNNING */
  bne t0, t1, put_to_seg          /* If the game is paused, end */

  la t0, CURR_STEP                /* Load the address of current step */
  lw t1, 0(t0)                    /* Load the current step */
  bne t1, zero, decrement_seg     /* If the step is not zero, decrement it */
  addi a0, zero, 1                /* If the 7 seg is zero, return 1 */
  j put_to_seg                    /* Return 1 and print 0 to seg */

  decrement_seg:
    addi t1, t1, -1               /* Decrement the current step by one */
    sw t1, 0(t0)                  /* Store the new number of steps */

  put_to_seg:
    la t0, CURR_STEP              /* Load the address of current step */
    lw t1, 0(t0)                  /* Load the current step */
    addi t0, zero, 3              /* Set index to 3 */
    mv t2, zero                   /* Set the 7 seg to zero */

    loop_through_seg:
      slli t3, t0, 2              /* Shift the index by 2 (multiply by 4) */
      srl t3, t1, t3              /* Shift current steps by 4 * index */
      andi t3, t3, 0xF            /* Get the last digit */

      la t4, font_data                    /* Load the address of font data */
      slli t3, t3, 2                      /* Multiply the value by 4 to get address */
      add t4, t4, t3                      /* Add it to the address */
      lw t3, 0(t4)                        /* Load the value for display */

      slli t2, t2, 8                      /* Shift the result by 4 to get next content */
      add t2, t2, t3                      /* Add it to 7 seg */

      addi t0, t0, -1                     /* Decrement index */
      bge t0, zero, loop_through_seg      /* If index is yero end, else loop */

  la t0, SEVEN_SEGS               /* Load the address of 7 segs */
  sw t2, 0(t0)                    /* Store the new value */
  ret                             /* Return */
/* END:decrement_step */

/* BEGIN:reset_game */
reset_game:
  addi sp, sp, -4                 /* Decrement sp */
  sw ra, 0(sp)                    /* Store the return address */

  la t0, CURR_STEP                /* Load the address of the current step */
  addi t1, zero, 1                /* Set the value of t1 to 1 */
  sw t1, 0(t0)                    /* Store the number 1 into current step */

  la t0, CURR_STATE               /* Load the current state address */
  li t1, INIT                     /* Load the initial state value */
  sw t1, 0(t0)                    /* Set current state to init */

  jal decrement_step              /* Decrement step */

  la t0, GSA_ID                   /* Load the GSA ID address */
  sw zero, 0(t0)                  /* Set the GSA ID to zero */

  la t0, SEED                     /* Load address of SEED */
  sw zero, 0(t0)                  /* Set seed to zero */
  mv a0, zero                     /* Set argument to 0 (id of the seed) */
  jal set_seed                    /* Set the seed to 0 */
  
  jal clear_leds                  /* Clear leds */
  jal draw_gsa                    /* Draw the new gsa */

  la t0, PAUSE                    /* Load the PAUSE address */
  li t1, PAUSED                   /* Load the value of PAUSED */
  sw t1, 0(t0)                    /* Set the value to paused */

  la t0, SPEED                    /* Load the SPEED address */
  li t1, MIN_SPEED                /* Load the value of MIN_SPEED */
  sw t1, 0(t0)                    /* Set the value to MIN_SPEED */

  lw ra, 0(sp)                    /* Load back the return address */
  addi sp, sp, 4                  /* Increment back sp */
  ret                             /* Return */
/* END:reset_game */

/* BEGIN:mask */
mask:
  addi sp, sp, -28                /* Decrement sp */
  sw ra, 0(sp)                    /* Store the return address */
  sw s0, 4(sp)                    /* Store s0 */
  sw s1, 8(sp)                    /* Store s1 */
  sw s2, 12(sp)                   /* Store s2 */
  sw s3, 16(sp)                   /* Store s3 */
  sw s4, 20(sp)                   /* Store s4 */
  sw s5, 24(sp)                   /* Store s5 */

  la t0, SEED                     /* Load address of seed */
  lw t1, 0(t0)                    /* Get seed value */

  la t0, MASKS                    /* Load address of masks */
  slli t1, t1, 2                  /* Shift by 2 current seed */
  add t0, t0, t1                  /* Add it to mask address */
  lw s0, 0(t0)                    /* Load the correct mask */

  li s4, N_GSA_LINES              /* Load the number of lines */
  li s5, N_GSA_COLUMNS            /* Load the number of columns */
  mv s2, zero                     /* Set index of outer loop */

  outer_loop_mask:
    lw s1, 0(s0)                  /* Load the mask element value */
    li t0, 0xFFF                  /* Load value of no walls */
    beq s1, t0, skip_walls        /* If there is no wall then skip */

    mv a0, s2                     /* Set the y-coordinate */
    jal get_gsa                   /* Get the gsa */
    and a0, a0, s1                /* Apply mask to gsa */
    mv a1, s2                     /* Set y-coordinate to set GSA */
    jal set_gsa                   /* Set GSA */

    mv s3, zero                   /* Set index of inner loop */
    li t0, BLUE                   /* Load blue value to t0 */
    la t1, LEDS                   /* Load the address of LEDS to t1 */

    inner_loop_mask:
      andi t2, s1, 1              /* Get current bit of GSA element */
      bne t2, zero, not_wall      /* If bit is not 0 there is no wall */

      slli t2, s2, 4              /* Shift the y-coordinate by 4 */
      add t2, t0, t2              /* Add the shifted y-coordinate and blue value */
      add t2, t2, s3              /* Add the x-coordinate to the blue */

      addi t3, zero, 1            /* Set the value to 1 (ON) */
      slli t3, t3, 16             /* Shift the ON value by 16 */
      add t2, t2, t3              /* Add the ON value to the blue variable */

      sw t2, 0(t1)                /* Store the new LED array to LEDS address */

      not_wall: 
        srli s1, s1, 1              /* Shift GSA element by one */
        addi s3, s3, 1              /* Increment inner loop index */
        blt s3, s5, inner_loop_mask /* If still in gsa emelent, loop */

    skip_walls:
      addi s0, s0, 4              /* Increment address of mask */
      addi s2, s2, 1              /* Increment outer loop index */
      blt s2, s4, outer_loop_mask /* If still in gsa, loop */

  lw ra, 0(sp)                    /* Load back the return address */
  lw s0, 4(sp)                    /* Load back s0 */
  lw s1, 8(sp)                    /* Load back s1 */
  lw s2, 12(sp)                   /* Load back s2 */
  lw s3, 16(sp)                   /* Load back s3 */
  lw s4, 20(sp)                   /* Load back s4 */
  lw s5, 24(sp)                   /* Load back s5 */
  addi sp, sp, 28                 /* Increment back sp */
  ret                             /* Return */
/* END:mask */

/* 7-segment display */
font_data:
  .word 0x3F
  .word 0x06
  .word 0x5B
  .word 0x4F
  .word 0x66
  .word 0x6D
  .word 0x7D
  .word 0x07
  .word 0x7F
  .word 0x6F
  .word 0x77
  .word 0x7C
  .word 0x39
  .word 0x5E
  .word 0x79
  .word 0x71

  seed0:
	.word 0xC00
	.word 0xC00
	.word 0x000
	.word 0x060
	.word 0x0A0
	.word 0x0C6
	.word 0x006
	.word 0x000
  .word 0x000
  .word 0x000

seed1:
	.word 0x000
	.word 0x000
	.word 0x05C
	.word 0x040
	.word 0x240
	.word 0x200
	.word 0x20E
	.word 0x000
  .word 0x000
  .word 0x000

seed2:
	.word 0x000
	.word 0x010
	.word 0x020
	.word 0x038
	.word 0x000
	.word 0x000
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000

seed3:
	.word 0x000
	.word 0x000
	.word 0x090
	.word 0x008
	.word 0x088
	.word 0x078
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000


# Predefined seeds
SEEDS:
  .word seed0
  .word seed1
  .word seed2
  .word seed3

mask0:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
  .word 0xFFF
  .word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF
  .word 0x1FF
  .word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
  .word 0x7FF
  .word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

MASKS:
  .word mask0
  .word mask1
  .word mask2
  .word mask3
  .word mask4

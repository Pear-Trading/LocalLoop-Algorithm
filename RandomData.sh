#!/bin/bash

#Input param 1 num of rows
#FIXME error checking
numRows=$1;

minUserId=1;
maxUserId=50;
minValue=1;
maxValue=100;

#https://unix.stackexchange.com/questions/157250/how-to-efficiently-generate-large-uniformly-distributed-random-integers-in-bas
#First param lowest value
#Second param highest value
function rnd()
{
  echo $(( $RANDOM % ($2 + 1 - $1) + $1 ));
}

counter=1;
while (( $counter <= $numRows )); do
  fromId=$(rnd $minUserId $maxUserId);
  toId=$(rnd $minUserId $maxUserId);
  value=$(rnd $minValue $maxValue);

  while (( $fromId == $toId )); do
    toId=$(rnd $minUserId $maxUserId);
  done
  
  echo "${counter},${fromId},${toId},${value}";

  counter=$(( $counter + 1 ));

done

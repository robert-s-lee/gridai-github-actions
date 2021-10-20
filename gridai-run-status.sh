# determine status of previous grid run command
#
          cmd_err_cnt=0
          RUN_STATUS=unknown
          grid status --export json ${RUN_NAME} > grid.status.log 2>&1
          if [[ "$?" != 0 ]]; then
              (( cmd_err_cnt = cmd_err_cnt + 1 ))
          else
            JSON_FILE=$(cat grid.status.log | grep Exported | awk '{print $5}')
            RUN_STATUS=$(cat ${JSON_FILE} | jq -r -c '.[] | .status')
          fi
          # pool at 1 min interval
          while [ "${RUN_STATUS}" = 'queued' -o "${RUN_STATUS}" = 'running' -o "${RUN_STATUS}" = 'pending' -o "${RUN_STATUS}" = 'unknown' ]; do 
            echo "${RUN_NAME}:${RUN_STATUS} waiting ${{ inputs.poll_sec_interval }} sec for the next status"
            sleep ${{ inputs.poll_sec_interval }}
            grid status --export json ${RUN_NAME} > grid.status.log 2>&1
            if [[ "$?" != 0 ]]; then
              (( cmd_err_cnt = cmd_err_cnt + 1 ))
              echo "Error from grid status command: # ${cmd_err_cnt}"
              cat grid.status.log
              RUN_STATUS="unknown"
              if [[ ${cmd_err_cnt} > ${{ inputs.max_cmd_err_cnt }} ]]; then
                break
              fi
            else  
              JSON_FILE=$(cat grid.status.log | grep Exported | awk '{print $5}')
              RUN_STATUS=$(cat ${JSON_FILE} | jq -r -c '.[] | .status')
            fi
          done
          echo "${RUN_NAME}:${RUN_STATUS}"
          # only continue on successful completion
          case ${RUN_STATUS} in
            completed|succeeded)
              echo "${RUN_NAME}:completed"
              ;;
            *)
              echo "Error: ${RUN_NAME} did not finish with completed or succeeded"
              exit 1
          esac
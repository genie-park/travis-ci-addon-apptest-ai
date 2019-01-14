# travis-ci-addon-apptest-ai
travis ci addon for apptest ai service
# How to use this addon for adnroid build
  - clone this repository at intstall phase
      ```
      install:
      - git clone https://github.com/genie-park/travis-ci-addon-apptest-ai
      - chmod +x ./travis-ci-addon-apptest-ai/phase.sh
      ```
  - set up apptest ai service information : binary(*.ipa, *.apk) path to test, access_key, project id 
      ```
      script:  
        - export binary_path=./app/build/outputs/apk/debug/app-debug.apk
        - export access_key=d0b20cd289994be0e423e2c42f4c09fe
        - export project_id='793'
      ```
  - execute test 
      ```
      script:  
        - ./travis-ci-addon-apptest-ai/phase.sh
      ```

  

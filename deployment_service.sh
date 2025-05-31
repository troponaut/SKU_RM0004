#!/bin/bash

# Path and name of the new file.
file_path="/etc/systemd/system/"
service_name="uctronics-display.service"
exe_path=$(pwd)/"display"

version=$(cat /etc/os-release | grep "VERSION_ID" | awk -F= '{print $2}' | tr -d '"')
MODEL=$(cat /proc/device-tree/model)
converted_version=$((version))

deploy_function_service() {
    echo Create a new service "$file_path""$service_name".

    # Create a new file and write content into it.
    cat <<EOF |sudo tee  "$file_path""$service_name" >/dev/null
[Unit]
Description=UCtronics Display
After=multi-user.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=/bin/sh -c "'$exe_path'"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Check if the file has been successfully created and if the content has been written into it.
    if [ -e "$file_path" ]; then
        echo "New file created and text written successfully."
        return 0
    else
        echo "Failed to create new file or write text."
        return 1
    fi
}


install_service() {
    if [ -e "Makefile" ]; then
        make clean && make
        deploy_function_service
        # Check if the deployment was successful
        if [ $? -eq 0 ]; then
            echo "Reload the systemd daemon to load the new service unit configuration."
            sudo systemctl daemon-reload

            echo "Enable and start the service."
            sudo systemctl enable $service_name
            # sudo systemctl start $service_name

            # # Check if the service is active
            # if sudo systemctl is-active --quiet $service_name; then
            #     echo "Service $service_name has been successfully enabled and started."
            # else
            #     echo "Failed to start service $service_name."
            # fi

            echo "The script needs to be restarted to take effect. Do you need to restart now? (y/n)"
            read -r answer
            if [ "$answer" = 'y' ] || [ "$answer" = 'Y' ]; then
                sudo reboot
            else 
                exit 0
            fi

        else
            echo "Function service deployment failed. Aborting."
        fi

    else
        echo "Please run the script in the repository folder"
        exit 0
    fi
}
detect_pi_model() {
    if [[ $MODEL == *"Raspberry Pi 5"* ]]; then
        echo "Detected Raspberry Pi 5"
        return 0
    elif [[ $MODEL == *"Raspberry Pi 4"* ]]; then
        echo "Detected Raspberry Pi 4"
        return 0
    else
        echo "Unsupported Raspberry Pi model. Please use Raspberry Pi 4 or 5."
        return 1
    fi
}

BOOT_CONFIG="/boot/config.txt"

if [ $converted_version -ge 12 ]; then
    BOOT_CONFIG="/boot/firmware/config.txt"
fi

preparation_steps() {

    echo 'Make sure you have the following prerequisites set on /boot/config.txt'
    echo 'dtoverlay=gpio-shutdown,gpio_pin=4,active_low=1,gpio_pull=up,debounce=1000'
    echo 'dtparam=i2c_arm=on,i2c_arm_baudrate=400000'

}

if detect_pi_model; then
    preparation_steps
fi

# Deploy the function service
if [ -e "$file_path""$service_name" ]; then
    echo "Service already exists. Do you want to overwrite? (y/n)"
    read -r answer
    if [ "$answer" = 'y' ] || [ "$answer" = 'Y' ]; then
        install_service
    else 
        exit 0
    fi
else 
    install_service
fi

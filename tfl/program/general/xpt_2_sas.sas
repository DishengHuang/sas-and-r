%macro import_xpt_files(folder, libname, outpath);
    /* Assign libname to the desired output path */
    libname &libname "&outpath";

    /* Check if the library was successfully assigned */
    %if %sysfunc(libref(&libname)) ne 0 %then %do;
        %put ERROR: Library &libname could not be assigned to &outpath.;
        %return;
    %end;

    /* Assign the folder containing the .xpt files */
    filename xptdir "&folder";

    data _null_;
        length xptfile $100;
        did = dopen('xptdir');  /* Open directory */
        if did = 0 then
            put "ERROR: Could not open directory &folder";
        else do;
            numfiles = dnum(did);
            do i = 1 to numfiles;
                xptfile = dread(did, i);
                if scan(xptfile, -1, '.') = 'xpt' then do;
                    call execute(cats('libname xptlib xport "', "&folder/", xptfile, '";'));
                    call execute(cats('proc copy in=xptlib out=', "&libname", '; run;'));
                end;
            end;
            rc = dclose(did);  /* Close the directory */
        end;
    run;

    /* Clear the filename assignment */
    filename xptdir clear;
%mend import_xpt_files;

/* Call the macro with the output path specified */
%import_xpt_files(folder=/home/u44419478/TFL/xpt_data/, libname=mylib, outpath=/home/u44419478/TFL/sas_data/);

/* Verify datasets imported in the library */
proc contents data=mylib._all_;
run;



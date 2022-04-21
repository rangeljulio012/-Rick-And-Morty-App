import React from 'react';
import Header from '../../components/header';
import { Outlet} from "react-router-dom";

function DefaultLayout({children}){

    return(
        <>
            <Header/>
                <main>
                    <Outlet />
                    {children}
                </main>
            {/*<Footer/>*/}
        </>
    )
}

export default DefaultLayout; 
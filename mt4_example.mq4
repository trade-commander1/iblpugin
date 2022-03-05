//+------------------------------------------------------------------+
//|                                                ibplugin_demo.mq4 |
//|                              Copyright 2020, trade-commander.com |
//|                                 https://www. trade-commander.com |
//+------------------------------------------------------------------+

// -------------------------------------------------------------------
// Expert demonstrating use of IBPlugin
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// This expert is demonstrates the most important functions
// of IBPlugin
// - listing most important account information     [#1]
// - list all NON ZERO positions                    [#2]
// - list all pending orders placed by this client   [#3]
// - deleting those pending orders                  [#3.1]
// - placing some pending orders                    [#4]
// - changing some pending orders                   [#4.1]

// - placing SELL MKT order                         [#5]
// - placing another SELL MKT order                 [#6]
// - Close positions opened by this SELL MKT order  [#6.1]
// - close positions of contract                     [#7]
// -------------------------------------------------------------------
#property copyright "Copyright 2020, trade-commander.com"
#property link      "https://www. trade-commander.com"
#property version   "1.00"
#property strict

const int __tc_version=1;

#include <trade-commander/ibplugin/ibpluginif.mqh>
//#include <trade-commander/gui_objects.mqh>
//#include <trade-commander/ibplugin/ibplugin_eula.mqh>


//+------------------------------------------------------------------+
//| input parameters                                   |
//+------------------------------------------------------------------+

// IBKR contract parameter
input int         i_conid                             = 0;         // Conid of IBKR contract. If > 0, it identifies the IBKR Contract for symbol, otherwise
                                                                   // it makes a lookup in IBplugin if there is a conid mapped to chart symbol
                                                                   // How to get conid for IBKR contract is shown in this video: https://youtu.be/ZNwjnb0Lu-U

// [[ TWS / Gateway connection parameter                                                              
input string      i_ip                                = "";        // IP address of API (TWS/Gateway) (default: local host)
input int         i_port                              = 7496;      // Port of API (this number should be in the API settings of TWS / GW)
// ]] TWS / Gateway connection parameter

input int         i_shares                            = 50000;     // Number of default shares for order     

input int           i_sl_pts                          = 0;             // Stop Loss points. Attention: MT points used
input int           i_tp_pts                          = 0;             // Take profit points. Attention: MT points used
input string        i_comment                         = "IBPLUIGIN_DEMO";   // Custom comment for order (can be seen in orderref field of tradelist)
// ]] order parameter                                                                   
             

// important for FA accounts only
input string            i_fa_alloc_type                     = "group";   // alloc type (FA only):  can be 'account','group' or 'profile'
input string            i_fa_alloc_name                     = "g3";     // alloc name (FA only):  name of account,group or profile;Group can have default 'All'
input string            i_fa_alloc_method                   = "";        // alloc method (FA only):  group/profile method
input string            i_fa_percentage                     = "";        // alloc percentage (FA only):  for group method PctChange only
// ]] order parameter                                                                   

input int         i_loglevel                          = 3;         // Log Severity: 1=system...6=verbose.
                                                                   // Logfiles are stored in user/documents/trade-commander.com/ibplugin/host_applications/<this_app>/log

//+------------------------------------------------------------------+
//| Script globals                                                   |
//+------------------------------------------------------------------+

// allocation id for usage with FA accounts
int __id_allocation=0;

// connection id (index) to denote what connction to be used for function calls
// Must be greater 0.
const int __connection_id=1;

// Unique IBKR contract id for chart symbol
int __conid=0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // create config name from terminal name
    string config_name=StringFormat("mt_%s",TerminalName());
    
    // call init script with config name
    // If this config is not yet created, it gets created and the symbol database
    // is copied from config "default".
    int iret=ibgINIT_SCRIPT(config_name);
    
    // Get the conid for calling symbol (this mapping should be in the database)
    __conid=ibgNAME_TO_UID(Symbol());
    
    // symbol not mapped, stop here.
    // Do a symbol mapping in the database of
    if(__conid <= 0)
    {
        string msg=StringFormat("There is no IBKR contract mappe for symbol=%s. Please do the symbol mapping with the IBPlugin tool.",Symbol());              
        int  ret=MessageBox(msg,"Symbol not mapped",0);
        
        return(INIT_FAILED);
    }
     
    // ----------------------------- 
    // Connect to TWS at IP and port
    // NOTE: No need to call this function more than once.
    // The IBPlugin will keep connection
    // let clientid hash of conifguration name.
    int clientid=-1;
    // use 2 channels. So 1 channel only for order related actions.
    int nbr_channels=2;
    // wait 25 seconds for connection completed
	// take a high timeout: The more accounts managed by connections and the more pending orders and opened positions
	// the longer the initial download of those data. It is recommendable to have all position-, account- and active
	// order data downloaded, before proceed. 
	// The timeout refers to this state: initial requests done (ibgCONNECT return >= 3).
    
    iret=ibgCONNECT (__connection_id,i_ip,i_port, clientid,nbr_channels,25000);
    PrintFormat("Connection status=%d",iret); // >= 3 is fine

    // create allocation, when account parameter known. For this, we need a successfull connection     
    if(iret > 2)
         // create an allocation id for given allocation input parameters (only important for FA accounts)
         __id_allocation=ibgCREATE_ALLOCATION(__connection_id,i_fa_alloc_type,i_fa_alloc_name,i_fa_alloc_method, i_fa_percentage);
     
       
    // --------------------------------------------	
	// [#1] Print out some important account information	
	Print("+++ Account Data");
	// Get Equity with Loan Value for all accounts managed by API connection
	double ret_double=ibgACCOUNT_INFO (__connection_id,(int) tcACCOUNT_EQUITY,"");   
	PrintFormat("EWL=%.0f",ret_double);
	// Get Margin
	ret_double=ibgACCOUNT_INFO(__connection_id,tcACCOUNT_MARGIN,"");
	PrintFormat("Margin=%.0f",ret_double);
	// Get Number of managed accounts
	ret_double=ibgACCOUNT_INFO(__connection_id,tcACCOUNT_NBR_ACCOUNTS,"");
	PrintFormat("# managed accounts=%.0f",ret_double);
	// Get Is demo account flag (> 0: connected IB account is demo/paper)
	ret_double=ibgACCOUNT_INFO(__connection_id,tcACCOUNT_ACCOUNT_IS_DEMO,"");
	PrintFormat("is demo=%s",(ret_double > 0 ? "yes" : "no"));
	// Get list of managed accounts
	string ret_str=ibgACCOUNT_INFO_STR(__connection_id,tcACCOUNT_LIST,"");
	PrintFormat("account list=%s",ret_str);	
	Print("--- Account Data");


    // --------------------------------------------
	// [#2] List all non zero positions:
	Print("+++ positions START");
	// create a snapshot of current non zero positions (resolution down to (sub-) account)
	int total_objects=ibgCREATE_POSITION_SNAPSHOT(__connection_id);
	Print("#positions=",total_objects );
	// list all positions by index
	for(int idx=0;idx < total_objects;++idx)
    {
		// print out a string fingerprint of positions (12 is id of position fingerprint;4 id of signed position;5 id of avg. entry price)		
		string fingerprint=ibgPOSITION_INFO_STR(idx,tcpi_str_dmp);
		Print(fingerprint);
		// to get double values returned use function <ibgPOSITION_INFO_DBL>
	}
	Print("--- positions END");



    // -----------------------------------------------
	// [#3] List all pending orders placed by this client
	// (The <clientid> passed to ibplugin.dll function selects the
	//  orders that can be seen and mastered by an API client.
	// Each ibplugin.dll instance is an API client.
	// Normally, you do not set the clientid or just pass -1 as the
	// IB trader does it: This will create a clientid based on hash value
	// of your configuration. This way, you be sure to control all orders
	// that have been created by this configuration.
	
    total_objects=ibgCREATE_PENDING_ORDER_SNAPSHOT (__connection_id, 0,1);
	Print("+++ pending orders START. #=",total_objects);
    long uid_order=0;
	// list all positions by index
	for(int idx = 0;idx < total_objects;++idx)
    {

		// print out a string fingerprint of order (1020 is id of order fingerprint)	
		// (the order attribute identifiers are usually listed in help file:
		// C:/Program Files/trade-commander.com/IBPlugin/documentation/tbl_order_attributes.html	)
		string fingerprint=ibgORDER_INFO_STR(idx,1020);
		Print(fingerprint);
		// to get double values returned, use function <ibgPOSITION_INFO_DBL>
		// to get int64 values (order uids) returned, use function <ibgPOSITION_INFO_INT64>
		// to get int values returned, use function <ibgPOSITION_INFO_INT>
		
		// -----------------------------
		// cancel current order[idx]
		// get its uid
		uid_order=ibgORDER_INFO_INT64(idx,1011);
		if(uid_order > 0)
		{
		    // [#3.1]
			int ret_int=ibgORDER_DELETE(__connection_id,uid_order);		
		}
	}
    Print("--- pending orders END");


    // -------------------------------------------------------------------
	// [#4] Place 5 limit orders (which are cancelled on next run (see above)
	// 64 bit integer order uid
	Print("+++ place some pending orders");
	string order_attribute_str="";
	for(int idx = 0;idx < 5;++idx)
	{
		// create attribute string: BUY LMT size=50000
		order_attribute_str="#1=50000#53=BUY#6=LMT";
		// modify price
		double lmt_price=Ask - (100.0 * Point() * (idx+1));
		// append limit price to attribute string
		order_attribute_str += StringFormat("#2=%.8f",lmt_price);

		double sl_price=lmt_price - (100.0 * Point() * (idx+1));
		// append stoploss price to attribute string
		order_attribute_str += StringFormat("#10002=%.8f",sl_price);


		double tp_price=lmt_price + (100.0 * Point() * (idx+1));
		// append take profit price to attribute string
		order_attribute_str += StringFormat("#10003=%.8f",tp_price);
		
		// place order
		uid_order=ibgORDER_SEND_STR(__connection_id, __conid,0, order_attribute_str, __id_allocation);
		
		// wait at most 1 second that order has been arrived at exchange (submitted status).
		// (this works only, when connected at this time.)
		if( uid_order > 0)
	    {
		
			int ret_int=ibgWAIT_SUBMITTED(uid_order,1000);
			if(ret_int == 1)
			{
			    Print("order uid=",uid_order ," submitted=",ret_int); // 1 means is submitted
			    
			    // modify order, wait 1 second for submitted confirmation
			    lmt_price=(lmt_price - 200.0 * Point());
        		sl_price=lmt_price - (100.0 * Point() * (idx+1));
        		tp_price=lmt_price + (100.0 * Point() * (idx+1));	
        		// sleep a second to be able to follow price change in TWS
        		Sleep(2000);	
        		//[#4.1]	    
        		// modify order, wait at most 1 seconds for submitted state confirmed
			    long long_ret=ibgORDER_MODIFY (__connection_id,uid_order,lmt_price, 0.0, sl_price, tp_price,1000);
			    
			    Sleep(2000);	
			}
		}		
	}
	Print("--- place some pending orders end");
	
	
	
	// [#5] place MKT SELL Order	
	Print("--- place MKT order");
	order_attribute_str="#1=150000#53=SELL#6=MKT";
	uid_order=ibgORDER_SEND_STR(__connection_id, __conid,0, order_attribute_str, __id_allocation);
	int ret_int=0;
	Print("uid MKT=",	uid_order);
	if(uid_order > 0)
	{
		// wait order for been filled
		// out: 1=order filled
		//      0=timeout
		//     -1=Order can't be filled (e.g. invalid for what reason ever)
		ret_int=ibgWAIT_FILLED(uid_order,5000);		
	}
	

	// [#6] place another MKT SELL Order	to demonstrate ibgORDER_CLOSE
	Print("--- place another MKT order and close it after fill");
	order_attribute_str="#1=50000#53=SELL#6=MKT";
	uid_order=ibgORDER_SEND_STR(__connection_id, __conid,0, order_attribute_str, __id_allocation);
	Print("uid MKT=",	uid_order);
	if( uid_order > 0)
	{
		// wait order for been filled
		// out: 1=order filled
		//      0=timeout
		//     -1=Order can't be filled (e.g. invalid for what reason ever)
		ret_int=ibgWAIT_FILLED(uid_order,5000);		
		
		if(ret_int == 1)
			// [#6.1] close position only raised by this order (so place opposite order)
			ret_int=ibgORDER_CLOSE (__connection_id, uid_order, 5000);
	}

	// [#7] close all positions for contract and ALL accounts
	// wait for position closed
	Print("--- close positions for symbol");
	ret_int=ibgPOSITION_CLOSE(__connection_id,__conid,"",5000);

	
       
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  
    ibgDEINIT_SCRIPT();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    
   
}

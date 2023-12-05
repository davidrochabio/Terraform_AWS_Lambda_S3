import boto3

from io import StringIO
from datetime import datetime

import requests
import numpy as np
import pandas as pd

def get_rates(currencies, to_currency):
    '''
    Get exchange rates for a list of currencies.

    Parameters:
    currencies (list): A list of currency codes.
    to_currency (str): The currency code to convert to.

    Returns:
    dict: A dictionary containing exchange rates for each currency in the list.
    '''
    rates = {}
    for currency in currencies:
        req = requests.get('https://open.er-api.com/v6/latest/' + currency)
        assert req.status_code == 200
        rates[currency] = req.json()['rates'][to_currency]
        
    return rates

def lambda_handler(event, context):

    #get bucket event
    s3_client = boto3.client('s3')
    source_bucket = event['Records'][0]['s3']['bucket']['name']
    source_key = event['Records'][0]['s3']['object']['key']
    
    # check if file matches
    if source_key == 'banking_dirty.csv':
        
        # get file from bucket
        resp = s3_client.get_object(Bucket=source_bucket, Key=source_key)
        
        # create pandas df
        df = pd.read_csv(resp['Body'], sep=',')
        
        # lower column names
        df.columns = [col.lower() for col in df.columns]
        
        # normalize date columns
        date_cols = ['birth_date', 'account_opened', 'last_transaction']
        for col in date_cols:
            if col == 'birth_date':
                df[col] = pd.to_datetime(df[col], dayfirst=False)
            else:
                df[col] = pd.to_datetime(df[col], dayfirst=True)
        
        # get rates for unique currencies in df
        # for this example we want to convert the amounts to CAD
        currencies = df['acct_curr'].unique()
        to_currency = 'CAD'
        rates = get_rates(currencies, 'CAD')
        
        # create column with the rate for each currency
        df['rate_' + to_currency] = df['acct_curr'].map(rates)
        
        # create column with account amount converted to CAD
        df['acct_amount_' + to_currency] = df['acct_amount'] * df['rate_' + to_currency]
        
        # create column with load date and time
        df['dataload_datetime'] = datetime.now()
        
        csv_buffer = StringIO()
        df.to_csv(csv_buffer)
        
        target_bucket = 'output-banking-clean'
        target_key = 'banking_clean.csv'

        # send file to target bucket
        s3_client.put_object(Body=csv_buffer.getvalue(),  Bucket=target_bucket, Key=target_key)
        
        print('Success -> file transfered')
    
    else:
        print('Wrong file')

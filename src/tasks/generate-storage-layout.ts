import fs from 'fs';
import { table } from 'table';
import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import isEqual from 'lodash.isequal';
import uniqWith from 'lodash.uniqwith';

interface StateVariable {
  contractName: string;
  name: string;
  slot: string;
  offset: number;
  type: string;
  numberOfBytes: string;
}
enum ExportType {
  TABLE,
  INLINE,
  TABLE_AND_INLINE,
  UNKNOWN,
}

const TABLE_FILE_NAME = `storage_layout_table.log`;
const INLINE_FILE_NAME = `storage_layout.log`;

const removeIdentifierSuffix = (type: string) => {
  const suffixIdRegex = /\d+_(storage|memory|calldata|ptr)/g; // id_memory id_storage
  const contractRegex = /^(t_super|t_contract)\(([A-Za-z0-9_]+)\)\d+/g; // t_contract(contractName)id
  const enumRegex = /(t_enum)\(([A-Za-z0-9_]+)\)\d+/g; // t_enum(enumName)id
  return type.replace(suffixIdRegex, '_$1').replace(contractRegex, '$1($2)').replace(enumRegex, '$1($2)');
};

const getAndPreprocessData = async (hre: HardhatRuntimeEnvironment): Promise<StateVariable[]> => {
  const data = await hre.storageLayout.getStorageLayout();
  const result = data.contracts.reduce(function (filtered: StateVariable[], row) {
    const stateVars: StateVariable[] = row.stateVariables.map((variable) => ({
      contractName: row.name,
      name: variable.name,
      slot: variable.slot,
      offset: variable.offset,
      type: removeIdentifierSuffix(variable.type),
      numberOfBytes: variable.numberOfBytes,
    }));
    if (stateVars.length == 0) {
      return filtered;
    }
    const result = uniqWith(filtered.concat(stateVars), isEqual);
    return result;
  }, []);
  return result;
};
class StorageLayoutFactory {
  static async build(env: HardhatRuntimeEnvironment, exportedType: ExportType): Promise<BaseStorageLayout[]> {
    const data = await getAndPreprocessData(env);
    switch (exportedType) {
      case ExportType.TABLE:
        return [new TableStorageLayout(env, data)];
      case ExportType.INLINE:
        return [new InLineStorageLayout(env, data)];
      case ExportType.TABLE_AND_INLINE:
        return [new TableStorageLayout(env, data), new InLineStorageLayout(env, data)];
      default:
        throw new Error('Invalid exported type');
    }
  }
}

abstract class BaseStorageLayout {
  env: HardhatRuntimeEnvironment;
  data: StateVariable[];
  constructor(env: HardhatRuntimeEnvironment, data: StateVariable[]) {
    this.env = env;
    this.data = data;
  }
  async prepareData(): Promise<StateVariable[]> {
    const data = await this.env.storageLayout.getStorageLayout();
    const result = data.contracts.reduce(function (filtered: StateVariable[], row) {
      const stateVars: StateVariable[] = row.stateVariables.map((variable) => ({
        contractName: row.name,
        name: variable.name,
        slot: variable.slot,
        offset: variable.offset,
        type: removeIdentifierSuffix(variable.type),
        numberOfBytes: variable.numberOfBytes,
      }));
      if (stateVars.length == 0) {
        return filtered;
      }
      const result = uniqWith(filtered.concat(stateVars), isEqual);
      return result;
    }, []);
    return result;
  }
  abstract getContent(): string;
  abstract getFilePath(): string;
  async export() {
    const filePath = this.getFilePath();
    try {
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
      fs.writeFileSync(filePath, '');
      fs.writeFileSync(filePath, this.getContent(), 'utf8');
      console.log(`Successful generate storage layout at ${filePath}`);
    } catch (err) {
      console.error(err);
    }
  }
}

class InLineStorageLayout extends BaseStorageLayout {
  getContent(): string {
    const lines: string[] = [];
    this.data.forEach((stateVar) => {
      const line = `${stateVar.contractName}:${stateVar.name} (storage_slot: ${stateVar.slot}) (offset: ${stateVar.offset}) (type: ${stateVar.type}) (numberOfBytes: ${stateVar.numberOfBytes})`;
      lines.push(line);
    });
    return lines.join('\n');
  }

  getFilePath(): string {
    return this.env.config.paths.newStorageLayoutPath + '/' + INLINE_FILE_NAME;
  }
}

class TableStorageLayout extends BaseStorageLayout {
  getContent(): string {
    const rows: string[][] = [['Contract', 'Name', 'Slot', 'Offset', 'Type', 'Number of bytes']];
    this.data.forEach((stateVar) => {
      rows.push(Object.values(stateVar));
    });
    return table(rows);
  }

  getFilePath(): string {
    return this.env.config.paths.newStorageLayoutPath + '/' + TABLE_FILE_NAME;
  }
}

/// @notice Generate storage layout.
task('generate-storage-layout')
  .addFlag('table', 'Export storage layout as table')
  .addFlag('inline', 'Export storage layout as inline')
  .setAction(async ({ table, inline }, hre) => {
    let exportedType: ExportType;
    if (table && inline) {
      exportedType = ExportType.TABLE_AND_INLINE;
    } else if (table) {
      exportedType = ExportType.TABLE;
    } else if (inline) {
      exportedType = ExportType.INLINE;
    } else {
      exportedType = ExportType.UNKNOWN;
    }

    const storageLayouts = await StorageLayoutFactory.build(hre, exportedType);
    await Promise.all(
      storageLayouts.map(async (storageLayout) => {
        await storageLayout.export();
      })
    );
  });
